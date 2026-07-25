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
