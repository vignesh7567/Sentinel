variable "name" {
  description = "Prefix name for resources"
  type        = string
}

variable "cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "azs" {
  description = "List of AZs to use"
  type        = list(string)
}

variable "private_subnets" {
  description = "List of CIDRs for private subnets (one per AZ)"
  type        = list(string)
}

variable "public_subnets" {
  description = "List of CIDRs for public subnets (one per AZ)"
  type        = list(string)
}