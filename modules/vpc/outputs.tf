output "vpc_id" {
  value = aws_vpc.this.id
}
output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}
output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}
output "private_route_table_ids" {
  description = "List of private route table IDs, one per AZ"
  value       = aws_route_table.private[*].id
}