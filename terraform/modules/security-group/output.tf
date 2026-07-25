output "bastion_sg_id" {
  value = aws_security_group.bastion_sg.id
}

output "eks_nodes_sg_id" {
  value = aws_security_group.eks_nodes_sg.id
}
