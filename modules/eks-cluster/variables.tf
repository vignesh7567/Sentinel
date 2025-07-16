variable "cluster_name" {
  type        = string
  description = "EKS cluster name"
}

variable "vpc_id" {
  type        = string
  description = "VPC to deploy EKS into"
}

variable "subnet_ids" {
  type        = list(string)
  description = "List of private subnet IDs for EKS nodes/API"
}

variable "eks_version" {
  type        = string
  default     = "1.27"
  description = "Kubernetes version"
}

variable "node_group_desired" {
  type        = number
  default     = 2
}

variable "node_group_instance_types" {
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_role_arn" {
  type        = string
  description = "Existing IAM role ARN for EKS node group"
}

variable "cluster_role_arn" {
  type        = string
  description = "Existing IAM role ARN for EKS cluster"
}

