resource "aws_instance" "bastion" {
  ami                    = "ami-0f918f7e67a3323f0"   # Amazon Linux 2023 (ap-south-1)
  instance_type          = "t3.micro"
  subnet_id              = var.subnet_id
  key_name               = var.key_name
  vpc_security_group_ids = [var.security_group_id]

  associate_public_ip_address = true

  tags = {
    Name = "production-bastion"
  }
}
