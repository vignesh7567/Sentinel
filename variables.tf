variable "region" {
  type    = string
  default = "eu-west-1"
}

variable "azs" {
  type    = list(string)
  default = ["eu-west-1a","eu-west-1b"]
}

variable "gateway_vpc_cidr" {
  type    = string
  default = "10.10.0.0/16"
}

variable "gateway_public_subnets" {
  default = ["10.10.1.0/24", "10.10.2.0/24"]
}

variable "gateway_private_subnets" {
  default = ["10.10.11.0/24", "10.10.12.0/24"]
}

variable "backend_vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "backend_public_subnets" {
  description = "Explicit CIDRs for the backend VPC public subnets"
  type        = list(string)
  default     = ["10.20.1.0/24", "10.20.2.0/24"]
}

variable "backend_private_subnets" {
  description = "Explicit CIDRs for the backend VPC private subnets"
  type        = list(string)
  default     = ["10.20.11.0/24", "10.20.12.0/24"]
}

# For the Gateway cluster
variable "gateway_cluster_role_arn" {
  type    = string
  default = "arn:aws:iam::721500739616:role/vignesh-eks-gateway-cluster-role"
}
variable "gateway_node_role_arn" {
  type    = string
  default = "arn:aws:iam::721500739616:role/vignesh-eks-gateway-node-role"
}

# For the Backend cluster
variable "backend_cluster_role_arn" {
  type    = string
  default = "arn:aws:iam::721500739616:role/vignesh-eks-backend-cluster-role"
}
variable "backend_node_role_arn" {
  type    = string
  default = "arn:aws:iam::721500739616:role/vignesh-eks-backend-node-role"
}
