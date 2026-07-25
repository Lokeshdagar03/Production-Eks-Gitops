resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = var.cluster_role_arn

  vpc_config {
    subnet_ids = var.private_subnet_ids

    endpoint_private_access = true
    endpoint_public_access  = true
  }

  tags = {
    Name = var.cluster_name
  }
}
resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-nodes"
  node_role_arn   = var.node_role_arn

  subnet_ids = var.private_subnet_ids

  instance_types = ["t3.micro"]

  scaling_config {
    desired_size = 2
    min_size     = 1
    max_size     = 2
  }

  capacity_type = "ON_DEMAND"

  tags = {
    Name = "${var.cluster_name}-nodes"
  }

  depends_on = [
    aws_eks_cluster.this
  ]
}
