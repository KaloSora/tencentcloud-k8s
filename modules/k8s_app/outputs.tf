output "namespace_names" {
  description = "Application namespaces to receive pull-only Harbor credentials"
  value       = local.environment_names
  depends_on  = [kubernetes_namespace.environment]
}
