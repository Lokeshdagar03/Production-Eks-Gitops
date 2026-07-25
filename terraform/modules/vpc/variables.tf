variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}


variable "public_subnet_1_cidr" {
  description = "CIDR for Public Subnet 1"
  type        = string
}

variable "public_subnet_2_cidr" {
  description = "CIDR for Public Subnet 2"
  type        = string
}

variable "private_subnet_1_cidr" {
  description = "CIDR for Private Subnet 1"
  type        = string
}

variable "private_subnet_2_cidr" {
  description = "CIDR for Private Subnet 2"
  type        = string
}

variable "availability_zone_1" {
  description = "Primary Availability Zone"
  type        = string
}

variable "availability_zone_2" {
  description = "Secondary Availability Zone"
  type        = string
}
