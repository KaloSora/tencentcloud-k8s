# Terraform-managed Harbor access

Application image pulling requires node-level Harbor access and a pull Secret
in each application namespace. The root Terraform configuration now wires both
into `module.k8s_cicd`; application Deployment and Service lifecycle remains in GitOps.

## Node configuration

`terraform_data.harbor_node_access` configures every CVM reported by
`module.k8s_cvm.registry_nodes`. It runs after the cluster and Ingress controller
exist, discovers the current Ingress Service ClusterIP, and applies the payload
in `templates/harbor_node_access.py` over the existing SSH connection.

The payload validates a merged Docker configuration before writing, backs up
changed files, updates only Harbor's `/etc/hosts` mapping and Docker HTTP
registry setting, then reloads Docker without restarting it. It verifies DNS,
Docker's active registry setting and the Harbor `/v2/` HTTP response.

Terraform reruns the provisioner when a node instance ID, public address,
Ingress ClusterIP, Harbor hostname or payload changes. New nodes and rebuilt
instances therefore receive configuration automatically. This post-cluster
resource deliberately does not modify the CVM initialization script or its hash,
so adopting it does not rerun kubeadm or replace existing CVMs.

Provisioners do not continuously detect manual drift in remote files. If someone
changes the node configuration, review a plan using, for example,
`-replace='module.k8s_cicd.terraform_data.harbor_node_access["node1"]'` to reconcile
that node again. Destroying the Terraform resource does not undo the node files;
node destruction removes them. Use the same staged bootstrap procedure as the
rest of this repository when recreating a cluster whose Kubernetes API does
not exist yet.

## Application pull credentials

`helm_release.application_pull_credentials` installs the local
`charts/harbor-app-pull` chart into the Harbor namespace. Terraform supplies
the namespaces created by `module.k8s_app` and references Harbor's existing
admin Secret by name. It manages:

- A ServiceAccount with namespace-scoped Roles and RoleBindings. Read/update
  permissions are limited to `harbor-docker-config`; create permission is
  restricted to the application namespaces. Kubernetes cannot restrict create
  by resource name.
- A ConfigMap containing the permanent in-cluster reconciliation code.
- A daily CronJob at **02:15 Asia/Shanghai**, with concurrent scheduled runs forbidden.

`kubernetes_job_v1.application_pull_credentials` runs the initial verification
with `wait_for_completion = true`. Terraform waits for this native Job, rather
than relying on Helm release readiness to prove credential bootstrap succeeded.

The Job adopts existing Secrets only after verifying their robot is active,
project-scoped, pull-only, and valid for more than seven days. It preserves valid
credentials and marks their metadata as managed. Missing, invalid or expiring
credentials are replaced with a new namespace-specific project robot with
repository pull permission only. The default lifetime is 90 days; the daily
CronJob renews within seven days of expiry. Existing shared valid credentials
are retained during migration; later rotations create separate robots for each
namespace. Old robots are not deleted because credentials may still be in use
elsewhere; their Harbor expiry still applies.

Passwords stay inside Kubernetes and Harbor; they are not outputs or values in
Terraform state. Do not manually delete a Secret to rotate it. To rerun initial
verification through Terraform, increment `application_pull_bootstrap_revision`
and review/apply the plan. The initial Job name includes the script/config hash;
the daily CronJob also repairs missing Secrets without requiring Terraform apply.

This runtime code is distributed by the Terraform-managed chart, not an operator-run
repair script. Both Job and CronJob require Harbor, Kubernetes API access and
normal Pod scheduling. Check failed Job logs and CronJob status if those services
are unavailable.

The shared HTTP client handles Harbor's 403 CSRF challenge with one bounded retry
using the response token, without printing headers or credential-bearing bodies.

## Validate and apply

Use the existing approved credential environment and protect plan files because
the root infrastructure configuration contains other sensitive values:

```sh
terraform -chdir=modules validate
helm lint modules/k8s_cicd/charts/harbor-app-pull
python3 -B -m unittest discover -s modules/k8s_cicd/test -p 'test_application_pull_auth.py'
python3 -B -m unittest discover -s modules/k8s_cicd/test -p 'test_harbor_node_access.py'
terraform -chdir=modules plan -var-file=dev.tfvars -out=/secure/path/infra.tfplan
terraform -chdir=modules apply /secure/path/infra.tfplan
```

Then verify:

```sh
kubectl -n harbor get jobs,cronjobs -l app.kubernetes.io/name=harbor-app-pull
kubectl -n harbor logs job/<initial-job-name>
kubectl -n dev rollout status deployment/k8s-demo-app --timeout=45s
kubectl -n dev get pods
kubectl -n argocd get application k8s-demo-app-dev
```

The migration may require targeting the Harbor release to avoid applying unrelated
root configuration changes. Targeted plans still include dependencies: inspect
every planned resource, and run a full plan afterwards to identify remaining work.

## Rebuild verification on 2026-10-24

The previous infrastructure was destroyed by the operator before verification.
Terraform recreated Kubernetes, CFS/Ingress, application namespaces and CI/CD.
Both nodes passed Docker registry and Harbor HTTP checks using the newly
discovered Ingress ClusterIP. The native credential Job completed for all four
namespaces. A test image was pushed to Harbor, and a temporary Pod on the worker
successfully pulled it using the dev pull-only Secret with `imagePullPolicy: Always`.
The temporary Pod was deleted. A Job cloned from the daily CronJob completed
and preserved all four valid Secrets unchanged; diagnostic Jobs were cleaned up.

The final full plan reported no changes for both node registry resources, the
application credential Helm release and the native verification Job. It still
listed the pre-existing unapplied monitoring stack and Argo CD bcrypt-derived
values update; those unrelated changes were not applied by this migration.

The operator-run repair scripts were removed only after those checks passed.
The Terraform provisioner payload and in-cluster controller code remain as
permanent implementation dependencies.

Destroying Harbor storage also destroys previously published images. GitOps
still references the old application's immutable digest, so that application
cannot recover until its artifact is restored or a new application image is
built and promoted. The confirmed old-app error is `artifact ... not found`,
separate from node DNS, HTTP registry access or pull credentials. Terraform
does not modify application release digests to work around missing artifacts.
