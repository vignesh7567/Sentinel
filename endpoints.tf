###############################################################################
# Gateway VPC Endpoints
###############################################################################

# S3 Gateway Endpoint
resource "aws_vpc_endpoint" "gw_s3" {
  vpc_id            = module.vpc_gateway.vpc_id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.vpc_gateway.private_route_table_ids
  tags = {
    Name = "gateway-s3-gateway-endpoint"
  }
}

# Interface Endpoints (ECR, KMS, SSM, Secrets Manager)
locals {
  gw_interface_services = [
    "com.amazonaws.${var.region}.ecr.api",
    "com.amazonaws.${var.region}.ecr.dkr",
    "com.amazonaws.${var.region}.kms",
    "com.amazonaws.${var.region}.ssm",
    "com.amazonaws.${var.region}.ssmmessages",
    "com.amazonaws.${var.region}.secretsmanager",
  ]
}

resource "aws_vpc_endpoint" "gw_iface" {
  for_each          = toset(local.gw_interface_services)
  vpc_id            = module.vpc_gateway.vpc_id
  service_name      = each.key
  vpc_endpoint_type = "Interface"
  subnet_ids        = module.vpc_gateway.private_subnet_ids
  security_group_ids = [
    aws_security_group.endpoint_sg_gateway.id
  ]
  private_dns_enabled = true

  tags = {
    Name = "gw-endpoint-${replace(each.key, "com.amazonaws.${var.region}.", "")}"
  }
}

###############################################################################
# Backend VPC Endpoints
###############################################################################

# S3 Gateway Endpoint
resource "aws_vpc_endpoint" "be_s3" {
  vpc_id            = module.vpc_backend.vpc_id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.vpc_backend.private_route_table_ids
  tags = {
    Name = "backend-s3-gateway-endpoint"
  }
}

# Interface Endpoints
locals {
  be_interface_services = [
    "com.amazonaws.${var.region}.ecr.api",
    "com.amazonaws.${var.region}.ecr.dkr",
    "com.amazonaws.${var.region}.kms",
    "com.amazonaws.${var.region}.ssm",
    "com.amazonaws.${var.region}.ssmmessages",
    "com.amazonaws.${var.region}.secretsmanager",
  ]
}

resource "aws_vpc_endpoint" "be_iface" {
  for_each          = toset(local.be_interface_services)
  vpc_id            = module.vpc_backend.vpc_id
  service_name      = each.key
  vpc_endpoint_type = "Interface"
  subnet_ids        = module.vpc_backend.private_subnet_ids
  security_group_ids = [
    aws_security_group.endpoint_sg_backend.id
  ]
  private_dns_enabled = true

  tags = {
    Name = "be-endpoint-${replace(each.key, "com.amazonaws.${var.region}.", "")}"
  }
}
