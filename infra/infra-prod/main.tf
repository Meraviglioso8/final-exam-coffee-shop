provider "aws" {
  region = var.region
}

terraform {
  backend "s3" {
    bucket  = "huyen-tfstate-backend"
    key     = "prod/terraform.tfstate"
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

#3) RDS Subnet Group (uses your VPC’s private subnets)
resource "aws_db_subnet_group" "postgres" {
  name        = "${var.name}-db-subnet-group"
  description = "RDS subnet group for ${var.name}"
  subnet_ids  = module.custom_vpc.private_subnet_ids
  tags        = var.common_tags
}

resource "aws_db_parameter_group" "custom_postgres" {
  name        = "${var.name}-custom-parameter-group"
  family      = "postgres17" 
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
  name        = "${var.name}-postgres-rds-credentials"
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

# # EKS
# EKS Cluster
resource "aws_eks_cluster" "huyen_prod_eks" {
  name     = "${var.name}-eks"
  role_arn = var.eks_cluster_role_arn

  # Use your VPC private subnets for worker nodes and control plane communication
  vpc_config {
    subnet_ids = concat(
      module.custom_vpc.public_subnet_ids,
      module.custom_vpc.private_subnet_ids
    )
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  tags = var.common_tags
}

# EKS Node Group (managed)
resource "aws_eks_node_group" "managed_nodes" {
  cluster_name    = aws_eks_cluster.huyen_prod_eks.name
  node_group_name = "${var.name}-node-group"
  node_role_arn   = var.eks_node_role_arn
  subnet_ids      = module.custom_vpc.public_subnet_ids

  scaling_config {
    desired_size = var.eks_node_desired_capacity
    max_size     = var.eks_node_max_capacity
    min_size     = var.eks_node_min_capacity
  }

  instance_types = var.eks_node_instance_types

  # Optional for bootstrapping etc
  remote_access {
    ec2_ssh_key = var.ec2_ssh_key_name
  }

  tags = merge(
    var.common_tags,
    {
      "Name" = "${var.name}-node"
    }
  )

  depends_on = [aws_eks_cluster.huyen_prod_eks]
}
