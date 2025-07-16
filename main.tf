module "vpc_gateway" {
  source          = "./modules/vpc"
  name            = "gateway"
  cidr            = var.gateway_vpc_cidr
  azs             = var.azs
  public_subnets  = var.gateway_public_subnets
  private_subnets = var.gateway_private_subnets
}

module "vpc_backend" {
  source          = "./modules/vpc"
  name            = "backend"
  cidr            = var.backend_vpc_cidr
  azs             = var.azs
  public_subnets  = var.backend_public_subnets
  private_subnets = var.backend_private_subnets
}

# VPC Peering
resource "aws_vpc_peering_connection" "gw_to_be" {
  vpc_id        = module.vpc_gateway.vpc_id
  peer_vpc_id   = module.vpc_backend.vpc_id
  auto_accept   = true
  tags = {
    Name = "gateway-backend-peering"
  }
}

# Add a route in each gateway-VPC private route table pointing to backend VPC
resource "aws_route" "gateway_to_backend" {
  count = length(module.vpc_gateway.private_route_table_ids)
  route_table_id            = module.vpc_gateway.private_route_table_ids[count.index]
  destination_cidr_block    = var.backend_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.gw_to_be.id
}

# Add a route in each backend-VPC private route table pointing to gateway VPC
resource "aws_route" "backend_to_gateway" {
  count = length(module.vpc_backend.private_route_table_ids)
  route_table_id            = module.vpc_backend.private_route_table_ids[count.index]
  destination_cidr_block    = var.gateway_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.gw_to_be.id
}

module "iam_roles" {
  source = "./modules/iam"
}


# EKS clusters
module "eks_gateway" {
  source                 = "./modules/eks-cluster"
  cluster_name           = "eks-gateway"
  eks_version            = "1.27"
  vpc_id                 = module.vpc_gateway.vpc_id
  subnet_ids             = module.vpc_gateway.private_subnet_ids
  cluster_role_arn    = module.iam_roles.gateway_cluster_role_arn
  node_role_arn       = module.iam_roles.gateway_node_role_arn
}

module "eks_backend" {
  source                 = "./modules/eks-cluster"
  cluster_name           = "eks-backend"
  eks_version            = "1.27"
  vpc_id                 = module.vpc_backend.vpc_id
  subnet_ids             = module.vpc_backend.private_subnet_ids
  cluster_role_arn    = module.iam_roles.backend_cluster_role_arn
  node_role_arn       = module.iam_roles.backend_node_role_arn
}
