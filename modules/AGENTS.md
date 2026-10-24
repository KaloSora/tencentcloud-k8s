# AGENTS.md

## 1. Project Overview

This repository provisions and operates a self-managed Kubernetes cluster on Tencent Cloud CVMs using Terraform and related cloud-native tools.

The project aims to build practical experience in Kubernetes platform engineering, infrastructure automation, observability, CI/CD, security hardening, and operational resilience.

### Planned Features

1. **Kubernetes CI/CD Platform**: Implement a Kubernetes-based CI/CD platform under `modules/k8s_cicd`. Manage supported application deployments and Kubernetes resources using Helm.
2. **etcd Backup and Recovery**: Build an automated etcd backup and recovery solution integrating the etcd API and Velero where appropriate. Clearly distinguish etcd control-plane state backups from Kubernetes application and persistent-volume backups.
3. **Zero-Trust Security**: Harden the Kubernetes cluster by applying least-privilege access, secure secret management, network restrictions, and other appropriate security controls.

### General Principles

- Prefer automation, repeatability, idempotency, and maintainability.
- Follow the existing repository structure and established implementation patterns.
- Prefer small, incremental changes over unnecessary architectural rewrites.
- Do not introduce additional tools or dependencies without a clear technical justification.
- Do not assume a feature is implemented simply because it appears in the planned features.

## 2. Repository and Architecture

- Inspect the relevant source files, Terraform modules, Helm configurations, and documentation before making changes.
- Reuse existing modules and conventions whenever practical.
- Keep changes within the relevant module unless cross-module changes are necessary.
- Preserve existing functionality unless a change explicitly requires modifying it.
- Do not reintroduce deprecated implementations when a replacement has already been adopted.
- The `modules/k8s_cicd` module uses Helm to manage supported platform components. Do not reintroduce the deprecated `cicd_init.sh.tpl` implementation.

Before modifying shared interfaces, module inputs, outputs, resource names, or dependencies, assess the impact on existing modules and deployed resources.

If the repository does not provide enough information to determine the intended behavior, explain the uncertainty and ask for clarification when it materially affects the implementation.

## 3. Development Standards

### 3.1 Terraform

- Follow the existing Terraform module structure and naming conventions.
- Use variables for configurable values instead of unnecessarily hardcoding environment-specific settings.
- Define appropriate variable types, descriptions, and validation rules.
- Define outputs only when they are needed by other modules or operators.
- Keep Terraform configuration formatted and validate changes with the appropriate Terraform commands.
- Review resource replacement, deletion, dependency changes, and state implications before proposing infrastructure changes.
- Avoid unnecessary changes to existing resource identities and state.
- Do not modify or delete Terraform state files as a workaround for configuration errors.

### 3.2 Helm and Kubernetes

- Manage application releases and supported Kubernetes resources through Helm where the existing architecture requires it.
- Keep chart versions, image versions, and other dependency versions explicit and reproducible where practical.
- Prefer configurable Helm values over hardcoded environment-specific settings.
- Follow Kubernetes conventions for labels, resource requests and limits, probes, RBAC, and security contexts where applicable.
- Validate Helm charts and render manifests before proposing deployment changes.
- Check compatibility among chart versions, Kubernetes versions, container images, and required APIs.
- Do not expose services publicly unless explicitly required and approved.

### 3.3 Scripts and Dependencies

- Prefer reliable, maintainable scripts with clear inputs, error handling, and meaningful exit codes.
- Avoid unnecessary dependencies, duplicate implementations, and undocumented manual steps.
- Verify referenced versions, image tags, chart versions, provider versions, and download URLs against authoritative sources when possible.
- Do not silently substitute a different dependency version or source when the requested one is unavailable.

## 4. Security Requirements

### 4.1 Secrets and Credentials

- Never hardcode cloud credentials, API keys, passwords, tokens, private keys, or other sensitive information in source code or configuration files.
- Never commit secrets, credential files, private keys, or sensitive environment-specific configuration to GitHub.
- Never read, display, copy, or execute `~/tencentcloud_env.sh`.
- Never execute `source ~/tencentcloud_env.sh` or any equivalent command that loads this file.
- Do not attempt to bypass this restriction by reading the file through another command or script.
- Do not print environment variables or credential values when troubleshooting.
- Use approved environment variables, secret-management mechanisms, or other explicitly authorized credential sources.
- If required credentials are unavailable, explain what is missing without attempting to retrieve them from restricted files.

### 4.2 Least Privilege

- Use the minimum permissions required for each component and operation.
- Avoid unnecessarily privileged containers, broad RBAC permissions, public endpoints, and unrestricted network access.
- Assess the security impact of new components and configuration changes.
- Do not weaken existing security controls merely to make a deployment succeed.

### 4.3 Sensitive Files and State

- Never commit Terraform state, plan files containing sensitive data, credentials, private keys, or generated artifacts containing secrets.
- Review `.gitignore` and the Git diff before committing changes.
- Treat logs, rendered manifests, Terraform plans, and debugging output as potentially sensitive.

## 5. Change and Approval Policy

### 5.1 Before Making Changes

For non-trivial tasks:

1. Inspect the relevant implementation and its dependencies.
2. Explain the proposed approach and identify affected components.
3. Identify security risks, potential resource replacement or deletion, and operational impact.
4. Ask for clarification or approval when the proposed implementation exceeds the user's stated scope.

Routine, low-risk code edits and read-only validation may proceed without separate approval unless otherwise instructed.

### 5.2 Before Applying Changes

**Explicit user approval is required before any operation that changes external or persistent system state.**

This includes, but is not limited to:

- `terraform apply` and other commands that modify remote infrastructure or Terraform state.
- `helm install`, `helm upgrade`, `helm uninstall`, and equivalent deployment operations.
- Applying or deleting Kubernetes resources.
- Creating, modifying, or deleting cloud resources.
- Running database recovery, restore, or other potentially destructive operations.
- Modifying persistent storage or executing commands that may cause data loss.

Before requesting approval:

1. Run the relevant non-destructive validation checks.
2. Present the proposed operation and its scope.
3. Explain expected changes, potential resource replacement or deletion, and material risks.
4. Present the Terraform plan, Helm diff, Kubernetes diff, or equivalent preview when available.
5. Identify any checks that could not be completed.

Wait for explicit approval before executing the operation.

Approval applies only to the reviewed operation and scope. If the plan changes materially, obtain approval again.

Never assume that a successful validation or a previous approval authorizes a subsequent deployment.

## 6. Validation and Testing

Every code or configuration change must receive appropriate validation before it is considered complete.

Use the following checks as applicable:

### Terraform

- Run `terraform fmt -check`.
- Run `terraform validate` in the appropriate initialized working directory.
- Review the Terraform plan when configuration changes affect infrastructure.
- Inspect unexpected resource creation, replacement, and deletion.
- Do not run `terraform apply` without explicit approval.

### Helm

- Run `helm lint` against the relevant chart.
- Render templates using `helm template` with the appropriate values.
- Validate chart dependencies and version compatibility.
- Review generated manifests for security, configuration, and resource-management issues.
- Use a Helm diff or equivalent preview when available before deployment.

### Kubernetes

- Validate manifests and resource references where appropriate.
- Check API compatibility against the target Kubernetes version.
- Verify relevant configuration, RBAC, probes, resource limits, and service exposure.
- Perform read-only cluster checks only when access is available and authorized.
- Do not modify the cluster without explicit approval.

### Dependencies and Documentation

- Verify dependency versions and referenced URLs against authoritative sources when possible.
- Check that configuration examples and documented commands match the implementation.
- Run relevant tests, linting, and static analysis when available.
- Report network restrictions, authentication failures, unavailable tools, and unexecuted checks honestly.

Do not claim that a test or validation passed unless it was actually executed and its result supports that conclusion.

## 7. Operational Safety

- Prefer read-only diagnostics before remediation.
- Do not delete or recreate infrastructure to resolve an issue without understanding the impact.
- Preserve existing data and recovery options when troubleshooting.
- For etcd and persistent-volume recovery, document the recovery scope, prerequisites, consistency requirements, and rollback or recovery procedure.
- Distinguish backup creation from successful restore validation.
- Do not perform failover, restore, or destructive recovery operations without explicit approval.
- Avoid exposing credentials or sensitive data in command output, logs, or reports.

## 8. Documentation and Reporting

- Update relevant documentation when configuration, architecture, dependencies, or operational procedures change.
- Document required variables, prerequisites, deployment steps, validation commands, and known limitations.
- Keep implementation and documentation consistent.
- Do not claim that planned features are complete unless their implementation and relevant validation support that claim.

When completing a task, provide a concise summary containing:

1. **Changes**: Files and components modified.
2. **Validation**: Commands executed and their actual results.
3. **Security**: Relevant security considerations.
4. **Operational Impact**: Potential resource changes, replacements, deletions, or downtime.
5. **Limitations**: Checks not performed and reasons.
6. **Next Steps**: Any remaining manual action or approval required.

## 9. Instruction Priority

- Follow applicable higher-priority system and platform instructions.
- Follow the user's explicit task requirements and approval boundaries.
- Follow this file for repository-specific conventions and safety requirements.
- If instructions conflict, do not silently choose an interpretation that could expose secrets, cause data loss, or modify infrastructure without authorization. Explain the conflict and request clarification when necessary.
