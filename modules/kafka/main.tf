resource "helm_release" "kafka" {
  name             = "kafka"
  repository       = "oci://registry-1.docker.io/bitnamicharts" # Updated to OCI registry
  chart            = "kafka"
  namespace        = var.namespace
  create_namespace = true
  version          = "26.3.0" # Specifying a concrete version

  timeout = 600 # Increase timeout for chart download

  set = [
    {
      name  = "global.storageClass"
      value = var.storage_class
    },
    {
      name  = "replicaCount"
      value = tostring(var.replica_count)
    },
    {
      name  = "persistence.size"
      value = var.storage_size
    },
    {
      name  = "resources.requests.cpu"
      value = var.resources.requests.cpu
    },
    {
      name  = "resources.requests.memory"
      value = var.resources.requests.memory
    },
    {
      name  = "resources.limits.cpu"
      value = var.resources.limits.cpu
    },
    {
      name  = "resources.limits.memory"
      value = var.resources.limits.memory
    },
    {
      name  = "metrics.kafka.enabled"
      value = "true"
    }
  ]
}