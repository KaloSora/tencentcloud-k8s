resource "helm_release" "this" {
  name             = var.component.release_name
  repository       = var.component.repository
  chart            = var.component.chart
  version          = var.component.version
  namespace        = var.component.namespace
  create_namespace = false
  timeout          = var.component.timeout

  values = var.values

  atomic        = var.component.atomic
  wait          = var.component.wait
  wait_for_jobs = var.component.wait_for_jobs
}
