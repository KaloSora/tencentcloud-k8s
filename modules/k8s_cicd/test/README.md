# CI/CD module tests

Run from the repository root:

```sh
python3 -B -m unittest discover -s modules/k8s_cicd/test -p 'test_*.py'
```

Tests use fake Harbor/Kubernetes APIs and temporary local Terraform projects.
They do not access the cluster or modify remote infrastructure. Terraform CLI
is required for the locals and token validation tests; otherwise those tests
are skipped. Runtime scripts remain in `../script/`.
