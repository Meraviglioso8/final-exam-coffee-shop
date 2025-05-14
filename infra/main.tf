provider "aws" {
  region = var.region
}

terraform {
  backend "s3" {
    bucket         = "huyen-tfstate-backend"
    key            = "dev/terraform.tfstate"
    region         = "us-west-2"
    encrypt        = true
  }
}

# VPC module
module "custom_vpc" {
  source                     = "./modules/vpc"
  cidr_block                 = var.cidr_block
  public_subnet_cidrs        = var.public_subnet_cidrs
  private_subnet_cidrs       = var.private_subnet_cidrs
  security_group_name        = var.security_group_name
  security_group_description = var.security_group_description
  security_group_ingress     = var.security_group_ingress
  security_group_egress      = var.security_group_egress
  common_tags                = var.common_tags
  name                       = var.name
}

# EC2 Instance
# module "docker_ec2" {
#   source  = "terraform-aws-modules/ec2-instance/aws"
#   version = "~> 5.0"

#   name                       = var.instance_name
#   ami                        = var.ami
#   instance_type              = var.instance_type
#   key_name                   = var.key_name
#   subnet_id                  = module.custom_vpc.public_subnet_ids[0] 
#   vpc_security_group_ids     = [module.custom_vpc.security_group_id]
#   associate_public_ip_address = true

#   user_data = <<-EOF
#     #!/bin/bash
#     yum update -y
#     yum install -y docker git nginx
#     systemctl start docker
#     systemctl enable docker
#     usermod -aG docker ec2-user
#     systemctl restart docker

#     systemctl start nginx
#     systemctl enable nginx

#     curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-$(uname -m) -o /usr/libexec/docker/cli-plugins/docker-compose
#     chmod +x /usr/libexec/docker/cli-plugins/docker-compose

#     docker compose version

#     git clone https://github.com/Meraviglioso8/final-exam-coffee-shop.git /home/ec2-user/coffee-shop

#     echo "${file("../dev/.env")}" > /home/ec2-user/coffee-shop/dev/.env

#     cd /home/ec2-user/coffee-shop/dev
#     docker compose up --build -d

#     sleep 2m

#     rm -f /etc/nginx/nginx.conf
#     echo "${file("../dev/nginx.conf")}" > /etc/nginx/nginx.conf

#     chown root:nginx /etc/nginx/nginx.conf
#     chmod 644 /etc/nginx/nginx.conf

#     nginx -t
#     systemctl restart nginx
#   EOF

#   tags = var.common_tags
# }




