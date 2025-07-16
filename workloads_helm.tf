################################################################################
## 1. Fetch EKS cluster details and auth (reuse your existing AWS provider)
################################################################################
#data "aws_eks_cluster" "backend" {
#  name = module.eks_backend.cluster_id
#}
#
#data "aws_eks_cluster_auth" "backend" {
#  name = module.eks_backend.cluster_id
#}
#
#data "aws_eks_cluster" "gateway" {
#  name = module.eks_gateway.cluster_id
#}
#
#data "aws_eks_cluster_auth" "gateway" {
#  name = module.eks_gateway.cluster_id
#}
#data "kubernetes_service" "gateway" {
#  provider = kubernetes.gateway
#
#  metadata {
#    name      = helm_release.gateway.name
#    namespace = helm_release.gateway.namespace
#  }
#}
#
################################################################################
## 2. Kubernetes & Helm providers for each cluster
################################################################################
#provider "kubernetes" {
#  alias                   = "backend"
#  host                    = data.aws_eks_cluster.backend.endpoint
#  cluster_ca_certificate  = base64decode(data.aws_eks_cluster.backend.certificate_authority[0].data)
#  token                   = data.aws_eks_cluster_auth.backend.token
#}
#
#provider "helm" {
#  alias                   = "backend"
#  kubernetes = {
#    host                   = data.aws_eks_cluster.backend.endpoint
#    cluster_ca_certificate = base64decode(data.aws_eks_cluster.backend.certificate_authority[0].data)
#    token                  = data.aws_eks_cluster_auth.backend.token
#    repository_cache  = pathexpand("${path.root}/.helm/cache")
#    repository_config = pathexpand("${path.root}/.helm/config")
#  }
#}
#
#provider "kubernetes" {
#  alias                   = "gateway"
#  host                    = data.aws_eks_cluster.gateway.endpoint
#  cluster_ca_certificate  = base64decode(data.aws_eks_cluster.gateway.certificate_authority[0].data)
#  token                   = data.aws_eks_cluster_auth.gateway.token
#}
#
#provider "helm" {
#  alias                   = "gateway"
#  kubernetes = {
#    host                   = data.aws_eks_cluster.gateway.endpoint
#    cluster_ca_certificate = base64decode(data.aws_eks_cluster.gateway.certificate_authority[0].data)
#    token                  = data.aws_eks_cluster_auth.gateway.token
#    repository_cache  = pathexpand("${path.root}/.helm/cache")
#    repository_config = pathexpand("${path.root}/.helm/config")
#  }
#}
#
#
#
################################################################################
## 3. Backend: simple internal web server (ClusterIP only)
################################################################################
#resource "helm_release" "backend" {
#  provider         = helm.backend
#  name             = "backend-svc"
#  chart            = "nginx"
#  repository       = "https://charts.bitnami.com/bitnami"
#  version          = "13.2.22"
#  namespace        = "backend"
#  create_namespace = true
#  atomic          = true    # rolls back on failure
#  cleanup_on_fail = true    # delete the failed release
#  wait            = true    # wait for all resources to be ready
#  timeout         = 600     # seconds (10 minutes)
#
#  set = [
#    { name = "service.type", value = "ClusterIP" }
#  ]
#}
#
################################################################################
## 4. Gateway: public NGINX reverse proxy forwarding to backend
################################################################################
#resource "helm_release" "gateway" {
#  provider         = helm.gateway
#  name             = "gateway-proxy"
#  chart            = "nginx"
#  repository       = "https://charts.bitnami.com/bitnami"
#  version          = "13.2.22"
#  namespace        = "gateway"
#  create_namespace = true
#  atomic          = true
#  cleanup_on_fail = true
#  wait            = true
#  timeout         = 600
#
#  # Expose as public LoadBalancer
#  set = [
#  {
#    name  = "service.type"
#    value = "LoadBalancer"
#  },
#
#  # Inject a custom NGINX server block to proxy to backend
#  {
#    name  = "nginxServerBlock"
#    value = <<-EOF
#      server {
#        listen 80;
#        location / {
#          proxy_pass http://backend-svc-backend.svc.cluster.local;
#        }
#      }
#    EOF
#  },
#
#  # Annotate the AWS ELB to only allow traffic from your gateway-cluster nodes’ SG
#  {
#    name  = "service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-security-groups"
#    value = module.eks_backend.node_security_group_id
#  } ]
#}
#
################################################################################
## Fetch the Service resources so we can output their IP/hostname reliably
################################################################################
#data "kubernetes_service" "backend_svc" {
#  provider = kubernetes.backend
#
#  metadata {
#    name      = helm_release.backend.name
#    namespace = helm_release.backend.namespace
#  }
#}
#
#data "kubernetes_service" "gateway_svc" {
#  provider = kubernetes.gateway
#
#  metadata {
#    name      = helm_release.gateway.name
#    namespace = helm_release.gateway.namespace
#  }
#}
#
################################################################################
## 5. Outputs so you can validate
################################################################################
#
#output "backend_service_clusterip" {
#  description = "ClusterIP of the backend service"
#  value       = data.kubernetes_service.backend_svc.spec[0].cluster_ip
#}
#
#output "gateway_lb_hostname" {
#  description = "Hostname of the gateway LoadBalancer"
#  value       = data.kubernetes_service.gateway_svc.status[0].load_balancer[0].ingress[0].hostname
#}
#
#
##output "backend_service_clusterip" {
##  value = jsondecode(helm_release.backend.values)["service"]["clusterIP"]
##}
#
##output "gateway_lb_hostname" {
##  value = data.kubernetes_service.gateway.status[0].load_balancer[0].ingress[0].hostname
##}
