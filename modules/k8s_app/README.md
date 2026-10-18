# Kubernetes application environments

This module creates the namespaces used to simulate application promotion:

- `dev`
- `uat`
- `preprod`
- `prod`

Every namespace enforces, audits, and warns against the Kubernetes Pod Security Standards `restricted` profile. 
The policy version is pinned to the cluster's Kubernetes major and minor version.

The module intentionally creates no workloads, RBAC, quotas, limit ranges, or network policies. 
Application lifecycle remains the responsibility of the GitOps delivery workflow.
