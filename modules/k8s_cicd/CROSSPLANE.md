# Crossplane and infrastructure GitOps

Terraform owns the Crossplane Helm release and `crossplane-system` namespace.
Argo CD owns subsequent declarations from the infrastructure GitOps repository.
Crossplane reconciles Kubernetes declarations through installed Providers; it
does not read Git itself. Existing Terraform-owned cloud resources stay under
Terraform ownership.

## Configuration

`dev.tfvars` enables the `crossplane` entry in `cicd_components`, using the
official `https://charts.crossplane.io/stable` repository and chart `1.20.3`.
`helm_values/crossplane.yaml` sets resources and container security settings.
No Providers, credentials, or cloud resources are installed by this change.

The new optional input is passed from the root module to `k8s_cicd`:

```hcl
argocd_infra_gitops_repo_url = "https://github.com/KaloSora/tencentcloud-infra-gitops.git"
```

An empty value disables infrastructure bootstrap. The existing
`argocd_gitops_repo_url` continues to bootstrap business applications. With
Argo CD enabled, a nonempty infrastructure URL requires an enabled component
named `crossplane`; Terraform checks this precondition.

`argocd-infra-bootstrap` is a separate `argocd-apps` Helm release. It installs
the restricted `infra-gitops-bootstrap` AppProject and two root Applications:

| Application | Repository path | Revision |
| --- | --- | --- |
| `infra-gitops-projects` | `argocd/projects` | `main` |
| `infra-gitops-applications` | `argocd/applications` | `main` |

These Applications self-heal with pruning disabled and have no cascading
deletion finalizer. Their project permits only AppProject and Application
objects in the Argo CD namespace. The repository's separate `infrastructure`
project controls permissions for future Provider/resource Applications.
Bootstrap waits for component Helm releases, including Crossplane core.

Argo CD explicitly uses annotation resource tracking and excludes generated
ProviderConfigUsage objects. Tencent Cloud managed-resource health requires
Ready and Synced, and surfaces reconciliation failures. ProviderConfig health
only indicates that configuration was declared; it does not validate cloud
authentication. Existing upstream health checks for Provider packages remain
available. Changing tracking applies to all Applications: review existing
Application sync status during rollout.

## Deployment and validation

1. Merge the infrastructure repository's `argocd/projects` and
   `argocd/applications` paths into `main` before deploying the bootstrap.
   The application entry point initially has an empty Kustomization.
2. For a private repository, provide Argo CD read credentials outside Git.
   The Jenkins promotion token is not automatically an Argo CD credential.
3. Run Terraform format/validation, render both Helm charts, and review a
   Terraform plan using the normal private variables. Do not print credentials
   or commit plan/state files. Review existing resource changes independently
   of the new Crossplane release.
4. Apply only after reviewing the plan and obtaining deployment approval.
5. Verify the Crossplane deployments and both root Applications are healthy.

Read-only checks after deployment:

```sh
kubectl -n crossplane-system get deployments,pods
kubectl -n argocd get applications infra-gitops-projects infra-gitops-applications
kubectl -n argocd get appprojects infrastructure infra-gitops-bootstrap
```

Crossplane `1.20.3` is pinned as an initial candidate for the configured
Kubernetes `1.28.8`. Successful Helm rendering is not proof of runtime
compatibility or current upstream support. Evaluate supported Kubernetes and
Crossplane upgrades separately; do not silently upgrade the foundation here.

Before adding cloud resources, pin and validate a Tencent Cloud Provider, wait
for its Installed/Healthy conditions and CRDs, then provide credentials and
ProviderConfig, and finally reconcile resources. Child-Application sync waves
alone do not establish those readiness gates. Extend the infrastructure
project's explicit resource allowlist only for the APIs actually required.

Cloud credentials must use a dedicated least-privilege identity. Keep credentials
out of Git and review management/deletion policies and Application deletion
propagation together. Disabled pruning alone is not deletion protection.
Back up the management cluster's resource identities and Secrets before relying
on Crossplane for persistent infrastructure. No existing Terraform resources
are adopted or migrated by this bootstrap.
