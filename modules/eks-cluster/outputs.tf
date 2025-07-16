output "cluster_id" {
  value = aws_eks_cluster.this.id
}
output "cluster_endpoint" {
  value = aws_eks_cluster.this.endpoint
}
output "cluster_certificate_authority_data" {
  value = aws_eks_cluster.this.certificate_authority[0].data
}
output "node_security_group_id" {
  description = "EKS node security group ID"
  value       = aws_eks_node_group.this.resources[0].remote_access_security_group_id
}