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

# ... existing code ...

resource "kubernetes_deployment" "kafka" {
  metadata {
    name      = "kafka"
    namespace = var.namespace
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = {
        app = "kafka"
      }
    }

    template {
      metadata {
        labels = {
          app = "kafka"
        }
      }

      spec {
        affinity {
          pod_anti_affinity {
            required_during_scheduling_ignored_during_execution {
              label_selector {
                match_expressions {
                  key      = "app"
                  operator = "In"
                  values   = ["kafka"]
                }
              }
              topology_key = "kubernetes.io/hostname"
            }
          }
          node_affinity {
            required_during_scheduling_ignored_during_execution {
              node_selector_term {
                match_expressions {
                  key      = "topology.kubernetes.io/zone"
                  operator = "In"
                  values   = var.availability_zones
                }
              }
            }
          }
        }

        container { # Changed from containers to container
          name  = "kafka"
          image = "confluentinc/cp-kafka:${var.kafka_version}"

          resources {
            limits = {
              cpu    = "2000m"
              memory = "4Gi"
            }
            requests = {
              cpu    = "1000m"
              memory = "2Gi"
            }
          }

          env {
            name  = "KAFKA_ZOOKEEPER_CONNECT"
            value = var.zookeeper_connect
          }

          env {
            name  = "KAFKA_ADVERTISED_LISTENERS"
            value = "INTERNAL://$(POD_IP):9092"
          }

          env {
            name  = "KAFKA_INTER_BROKER_LISTENER_NAME"
            value = "INTERNAL"
          }

          env {
            name  = "KAFKA_LISTENER_SECURITY_PROTOCOL_MAP"
            value = "INTERNAL:PLAINTEXT"
          }

          env {
            name = "POD_IP"
            value_from {
              field_ref {
                field_path = "status.podIP"
              }
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "kafka" {
  metadata {
    name      = "kafka"
    namespace = var.namespace
  }

  spec {
    selector = {
      app = "kafka"
    }

    port {
      port        = 9092
      target_port = 9092
    }

    type = "ClusterIP"
  }
}