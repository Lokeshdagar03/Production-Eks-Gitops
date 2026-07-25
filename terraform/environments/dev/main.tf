module "vpc" {
  source = "../../modules/vpc"

  project_name = "production-eks-gitops"
  environment  = "dev"

  vpc_cidr = "10.0.0.0/16"

  public_subnet_1_cidr  = "10.0.1.0/24"
  public_subnet_2_cidr  = "10.0.2.0/24"
  private_subnet_1_cidr = "10.0.3.0/24"
  private_subnet_2_cidr = "10.0.4.0/24"

  availability_zone_1 = "ap-south-1a"
  availability_zone_2 = "ap-south-1b"
}
module "security_group" {
  source = "../../modules/security-group"

  vpc_id = module.vpc.vpc_id
}
module "iam" {
  source = "../../modules/iam"
}
module "ec2" {
  source = "../../modules/ec2"

  subnet_id         = module.vpc.public_subnet_1_id
  security_group_id = module.security_group.bastion_sg_id
  key_name          = "DevOps"
}
module "eks" {
  source = "../../modules/eks"

  cluster_name     = "production-eks"
  cluster_role_arn = module.iam.cluster_role_arn
  node_role_arn    = module.iam.node_role_arn
  private_subnet_ids = [
    module.vpc.private_subnet_1_id,
    module.vpc.private_subnet_2_id
  ]
}
