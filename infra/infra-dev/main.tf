provider "aws" {
  region = var.region
}

terraform {
  backend "s3" {
    bucket  = "huyen-tfstate-backend"
    key     = "dev/terraform.tfstate"
    region  = "us-west-2"
    encrypt = true
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

#EC2 Instance
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

#     dnf install -y postgresql15

#     curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-$(uname -m) -o /usr/libexec/docker/cli-plugins/docker-compose
#     chmod +x /usr/libexec/docker/cli-plugins/docker-compose

#     docker compose version

#     git clone https://github.com/Meraviglioso8/final-exam-coffee-shop.git /home/ec2-user/coffee-shop

#     cat > /home/ec2-user/coffee-shop/dev/.env <<'ENVFILE'
#     ${file("../../dev/.env")}
#     ENVFILE

#     cd /home/ec2-user/coffee-shop/dev
#     set -o allexport
#     source .env
#     set +o allexport

#     echo "$DOCKER_PASS" | docker login --username "$DOCKER_USER" --password-stdin

#     docker compose up --build -d

#     sleep 1m

#     rm -f /etc/nginx/nginx.conf

#     cat > /etc/nginx/nginx.conf <<'ENVFILE'
#     ${file("../../dev/nginx.conf")}
#     ENVFILE

#     chown root:nginx /etc/nginx/nginx.conf
#     chmod 644 /etc/nginx/nginx.conf

#     nginx -t
#     systemctl restart nginx
#   EOF

#   tags = var.common_tags
# }

# 3) RDS Subnet Group (uses your VPC’s private subnets)
resource "aws_db_subnet_group" "postgres" {
  name        = "${var.name}-db-subnet-group"
  description = "RDS subnet group for ${var.name}"
  subnet_ids  = module.custom_vpc.private_subnet_ids
  tags        = var.common_tags
}

resource "aws_db_parameter_group" "custom_postgres" {
  name        = "${var.name}-custom-parameter-group"
  family      = "postgres17"   # match your engine version family
  description = "Custom parameter group with SSL disabled"

  parameter {
    name  = "rds.force_ssl"
    value = "0"
  }

  tags = var.common_tags
}

#4) PostgreSQL RDS instance
resource "aws_db_instance" "postgres" {
  identifier             = "${var.name}-postgres"
  engine                 = "postgres"
  db_name                = var.db_name
  port                        = var.db_port
  multi_az                    = var.db_multi_az
  backup_retention_period     = var.db_backup_retention_period
  storage_type                = var.db_storage_type
  publicly_accessible         = var.db_publicly_accessible
  instance_class         = var.db_instance_class
  allocated_storage      = var.db_allocated_storage
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  vpc_security_group_ids = [module.custom_vpc.security_group_id]
  skip_final_snapshot    = var.db_skip_final_snapshot
  deletion_protection    = var.db_deletion_protection

  parameter_group_name = aws_db_parameter_group.custom_postgres.name

  tags                   = var.common_tags
}

# 5) Store credentials in Secrets Manager
resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "${var.name}-postgresdb-rds-credentials"
  description = "Master credentials for RDS PostgreSQL"
  tags        = var.common_tags
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id     = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    engine   = aws_db_instance.postgres.engine
    host     = aws_db_instance.postgres.address
    port     = aws_db_instance.postgres.port
    dbname   = var.db_name
  })

  depends_on = [aws_db_instance.postgres]
}




