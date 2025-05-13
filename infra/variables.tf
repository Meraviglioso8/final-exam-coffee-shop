# Region for the AWS provider
variable "region" {
  description = "The AWS region to deploy resources in"
  type        = string
  default     = "us-east-2"  # Default region if not provided
}

# EC2 Instance related variables
variable "instance_name" {
  description = "Name of the EC2 instance"
  type        = string
  default     = "docker-host"
}

variable "ami" {
  description = "AMI ID for the EC2 instance"
  type        = string
}

variable "instance_type" {
  description = "Instance type for the EC2 instance"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Name of the key pair to associate with the EC2 instance"
  type        = string
}

# Common tags
variable "common_tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {
    Environment = "dev"
    Owner       = "huyen-tran"
  }
}

variable "name" {
  description = "Base name for all VPC resources"
  type        = string
  default     = "huyen-final-exam-vpc"
}

variable "cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "enable_dns_support" {
  description = "Enable DNS support in the VPC"
  type        = bool
  default     = true
}

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames in the VPC"
  type        = bool
  default     = true
}

variable "instance_tenancy" {
  description = "Tenancy for instances (default or dedicated)"
  type        = string
  default     = "default"
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
}


variable "security_group_name" {
  description = "Name of the security group"
  type        = string
  default     = "huyen-final-exam-vpc-sg"
}

variable "security_group_description" {
  description = "Description for the security group"
  type        = string
  default     = "Default security group for huyen-final-exam-vpc"
}

variable "security_group_ingress" {
  description = "List of ingress rule objects"
  type = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  default = [
    {
      description = "Allow SSH"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

variable "security_group_egress" {
  description = "List of egress rule objects"
  type = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  default = [
    {
      description = "Allow all outbound"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {
    Environment = "dev"
    Project     = "networking"
  }
}
