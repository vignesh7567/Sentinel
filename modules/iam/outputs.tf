output "gateway_cluster_role_arn" {
  value = aws_iam_role.eks_cluster_gateway.arn
}

output "gateway_node_role_arn" {
  value = aws_iam_role.eks_node_gateway.arn
}

output "backend_cluster_role_arn" {
  value = aws_iam_role.eks_cluster_backend.arn
}

output "backend_node_role_arn" {
  value = aws_iam_role.eks_node_backend.arn
}
