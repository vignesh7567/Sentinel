output "gateway_vpc_id" {
  value = module.vpc_gateway.vpc_id
}
output "backend_vpc_id" {
  value = module.vpc_backend.vpc_id
}
output "gateway_eks_endpoint" {
  value = module.eks_gateway.cluster_endpoint
}
output "backend_eks_endpoint" {
  value = module.eks_backend.cluster_endpoint
}
