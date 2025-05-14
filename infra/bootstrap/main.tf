provider "aws" {
  region = "us-west-2"
}

resource "aws_s3_bucket" "tfstate" {
  bucket = "huyen-tfstate-backend"

  tags = {
    Name = "Huyen Terraform State Bucket"
  }
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_key_pair" "ssh_key_dev" {
  key_name   = "huyen_ssh_key_dev" 
  public_key = file("~/.ssh/id_ed25519_dev.pub")  

  tags = {
    Name        = "huyen_ssh_key_dev"
    Environment = "dev"
    Owner       = "huyen-tran"
  }
}

resource "aws_key_pair" "ssh_key_prod" {
  key_name   = "huyen_ssh_key_prod" 
  public_key = file("~/.ssh/id_ed25519_prod.pub")  

  tags = {
    Name        = "huyen_ssh_key_dev"
    Environment = "dev"
    Owner       = "huyen-tran"
  }
}


