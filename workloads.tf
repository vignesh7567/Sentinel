###############################################################################
# 1. EKS Cluster Auth and Kubernetes Providers
###############################################################################

data "aws_eks_cluster" "backend" {
  name = module.eks_backend.cluster_id
}
data "aws_eks_cluster_auth" "backend" {
  name = module.eks_backend.cluster_id
}

data "aws_eks_cluster" "gateway" {
  name = module.eks_gateway.cluster_id
}
data "aws_eks_cluster_auth" "gateway" {
  name = module.eks_gateway.cluster_id
}

provider "kubernetes" {
  alias                  = "backend"
  host                   = data.aws_eks_cluster.backend.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.backend.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.backend.token
}

provider "kubernetes" {
  alias                  = "gateway"
  host                   = data.aws_eks_cluster.gateway.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.gateway.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.gateway.token
}

###############################################################################
# 2. Backend Cluster: Hello Service (ClusterIP)
###############################################################################

resource "kubernetes_namespace" "backend" {
  provider = kubernetes.backend
  metadata { name = "backend" }
  depends_on = [ module.eks_backend ]
}

resource "kubernetes_deployment" "backend_app" {
  provider = kubernetes.backend
  depends_on = [ module.eks_backend, kubernetes_namespace.backend ]
  metadata {
    name      = "backend-app"
    namespace = kubernetes_namespace.backend.metadata[0].name
    labels    = { app = "backend" }
  }

  spec {
    replicas = 2
    selector { match_labels = { app = "backend" } }

    template {
      metadata { labels = { app = "backend" } }
      spec {
        container {
          name  = "http-echo"
          image = "hashicorp/http-echo:0.2.3"
          args  = ["-text=Hello from backend"]
          port { container_port = 5678 }
        }
      }
    }
  }
}

resource "kubernetes_service" "backend_svc" {
  provider = kubernetes.backend
  depends_on = [ module.eks_backend, kubernetes_deployment.backend_app ]
  metadata {
    name      = "backend-svc"
    namespace = kubernetes_namespace.backend.metadata[0].name
  }
  spec {
    selector = { app = "backend" }
    port {
      port        = 80
      target_port = 5678
      protocol    = "TCP"
    }
    type = "ClusterIP"
  }
}

###############################################################################
# 3. Gateway Cluster: NGINX Reverse Proxy (LoadBalancer)
###############################################################################

resource "kubernetes_namespace" "gateway" {
  provider = kubernetes.gateway
  metadata { name = "gateway" }
  depends_on = [ module.eks_gateway ]
}

# Use the actual backend ClusterIP for proxy_pass
resource "kubernetes_config_map" "nginx_conf" {
  provider = kubernetes.gateway
  depends_on = [ kubernetes_namespace.gateway ]
  metadata {
    name      = "nginx-config"
    namespace = kubernetes_namespace.gateway.metadata[0].name
  }

  data = {
    "default.conf" = <<-EOT
      server {
        listen 80;
        location / {
          proxy_pass http://${kubernetes_service.backend_svc.spec[0].cluster_ip}:80;
        }
      }
    EOT
  }
}

resource "kubernetes_deployment" "gateway_proxy" {
  provider = kubernetes.gateway
  depends_on = [ module.eks_gateway, kubernetes_config_map.nginx_conf ]
  metadata {
    name      = "gateway-proxy"
    namespace = kubernetes_namespace.gateway.metadata[0].name
    labels    = { app = "gateway" }
  }

  spec {
    replicas = 2
    selector { match_labels = { app = "gateway" } }

    template {
      metadata { labels = { app = "gateway" } }
      spec {
        container {
          name  = "nginx"
          image = "nginx:latest"
          port  { container_port = 80 }

          volume_mount {
            name       = "nginx-config"
            mount_path = "/etc/nginx/conf.d"
          }
        }
        volume {
          name = "nginx-config"
          config_map { name = kubernetes_config_map.nginx_conf.metadata[0].name }
        }
      }
    }
  }
}

resource "kubernetes_service" "gateway_lb" {
  provider = kubernetes.gateway
  depends_on = [ module.eks_gateway, kubernetes_deployment.gateway_proxy ]
  metadata {
    name      = "gateway-lb"
    namespace = kubernetes_namespace.gateway.metadata[0].name
  }
  spec {
    selector = { app = "gateway" }
    port {
      port        = 80
      target_port = 80
      protocol    = "TCP"
    }
    type = "LoadBalancer"
  }
}

###############################################################################
# 4. Outputs
###############################################################################

output "backend_clusterip" {
  value       = kubernetes_service.backend_svc.spec[0].cluster_ip
  description = "ClusterIP of the internal backend service"
}

output "gateway_lb_address" {
  value       = kubernetes_service.gateway_lb.status[0].load_balancer[0].ingress[0].hostname
  description = "Public hostname of the NGINX gateway"
}
