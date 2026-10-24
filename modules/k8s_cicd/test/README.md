# CI/CD module tests

Run from the repository root:

```sh
python3 -B -m unittest discover -s modules/k8s_cicd/test -p 'test_*.py'
```

Tests use fake Harbor/Kubernetes APIs and temporary local Terraform projects.
They do not access the cluster or modify remote infrastructure. Terraform CLI
is required for the locals and token validation tests; otherwise those tests
are skipped. Runtime scripts remain in `../script/`.

The application pull tests verify credential adoption, pull-only permission,
expiry renewal and failure handling. Node access tests verify Docker validation
before writes, configuration preservation, idempotence and hot reload using
temporary files and mocked node commands. See `../HARBOR_ACCESS.md` for the
Terraform-managed deployment and runtime checks.
