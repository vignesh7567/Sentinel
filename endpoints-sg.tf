# Security Group for Interface Endpoints in gateway VPC
resource "aws_security_group" "endpoint_sg_gateway" {
  name        = "gateway-endpoints-sg"
  description = "Allow HTTPS from private subnets"
  vpc_id      = module.vpc_gateway.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.gateway_private_subnets
    description = "EKS nodes to endpoints"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "gateway-endpoints-sg"
  }
}

# Security Group for Interface Endpoints in backend VPC
resource "aws_security_group" "endpoint_sg_backend" {
  name        = "backend-endpoints-sg"
  description = "Allow HTTPS from private subnets"
  vpc_id      = module.vpc_backend.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.backend_private_subnets
    description = "EKS nodes to endpoints"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "backend-endpoints-sg"
  }
}
