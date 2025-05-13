region = "us-east-2"

# EC2 Instance Settings
instance_name = "huyen-dev-docker-host"
ami           = "ami-096af71d77183c8f8"
instance_type = "t3.micro"
key_name      = "huyen_ssh_key_dev"
name = "huyen-final-exam-dev-vpc"

cidr_block = "10.20.0.0/16"

public_subnet_cidrs = [
  "10.20.1.0/24",
  "10.20.2.0/24",
  "10.20.3.0/24"
]

private_subnet_cidrs = [
  "10.20.101.0/24",
  "10.20.102.0/24",
  "10.20.103.0/24"
]

security_group_name = "huyen-final-exam-dev-app-sg"

security_group_description = "HTTP and SSH from internet"

security_group_ingress = [
  {
    description = "Allow SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  },
  {
    description = "Allow HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
]

security_group_egress = [
  {
    description = "Allow HTTPS to anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
]

common_tags = {
  Environment = "dev"
  Owner       = "huyen-tran"
}


