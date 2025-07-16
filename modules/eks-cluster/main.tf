resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  version  = var.eks_version
  role_arn = var.cluster_role_arn

  #skip_role_validation = true # To test

  vpc_config {
    subnet_ids = var.subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true #false
    public_access_cidrs     = ["2.49.122.203/32"]
  }

  tags = {
    Name = var.cluster_name
  }
}

#resource "aws_iam_role" "eks_cluster" {
#  name               = "vignesh-eks-${var.cluster_name}-cluster-role"
#  assume_role_policy = data.aws_iam_policy_document.eks_cluster_assume.json
#   tags = {
#    ManagedBy = "Terraform"
#    Cluster   = var.cluster_name
#  }
#}
#
#data "aws_iam_policy_document" "eks_cluster_assume" {
#  statement {
#    effect = "Allow"
#    actions = ["sts:AssumeRole"]
#    principals {
#      type        = "Service"
#      identifiers = ["eks.amazonaws.com"]
#    }
#  }
#}
#
## Attach managed policies for EKS control plane
#resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
#  role       = aws_iam_role.eks_cluster.name
#  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
#}
#resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSServicePolicy" {
#  role       = aws_iam_role.eks_cluster.name
#  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
#}

# Node group role
#resource "aws_iam_role" "eks_node" {
#  name               = "vignesh-eks-${var.cluster_name}-node-role"
#  assume_role_policy = data.aws_iam_policy_document.eks_node_assume.json
#   tags = {
#    ManagedBy = "Terraform"
#    Cluster   = var.cluster_name
#  }
#}
#data "aws_iam_policy_document" "eks_node_assume" {
#  statement {
#    effect = "Allow"
#    actions = ["sts:AssumeRole"]
#    principals {
#      type        = "Service"
#      identifiers = ["ec2.amazonaws.com"]
#    }
#  }
#}
#resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodePolicy" {
#  role       = aws_iam_role.eks_node.name
#  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
#}
#resource "aws_iam_role_policy_attachment" "node_AmazonEKS_CNI_Policy" {
#  role       = aws_iam_role.eks_node.name
#  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSCNIPolicy"
#}
#resource "aws_iam_role_policy_attachment" "node_AmazonEC2ContainerRegistryReadOnly" {
#  role       = aws_iam_role.eks_node.name
#  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
#}




# Node group
resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-ng"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.subnet_ids
  #skip_role_validation = true

  scaling_config {
    desired_size = var.node_group_desired
    max_size     = var.node_group_desired + 1
    min_size     = 1
  }

  instance_types = var.node_group_instance_types
}
