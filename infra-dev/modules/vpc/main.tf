# Fetch availability zones for subnet placement
data "aws_availability_zones" "available" {}

# --- VPC -------------------------------------------------------------------
resource "aws_vpc" "custom_vpc" {
  cidr_block           = var.cidr_block
  enable_dns_support   = var.enable_dns_support
  enable_dns_hostnames = var.enable_dns_hostnames
  instance_tenancy     = var.instance_tenancy

  tags = merge(
    var.common_tags,
    { Name = var.name }
  )
}

# --- Internet Gateway -----------------------------------------------------
resource "aws_internet_gateway" "custom_vpc" {
  vpc_id = aws_vpc.custom_vpc.id

  tags = merge(
    var.common_tags,
    { Name = "${var.name}-igw" }
  )
}

# --- Public Subnets & Routing ---------------------------------------------
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.custom_vpc.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    var.common_tags,
    { Name = "${var.name}-public-${count.index + 1}" }
  )
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.custom_vpc.id

  tags = merge(
    var.common_tags,
    { Name = "${var.name}-public-rt" }
  )
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.custom_vpc.id
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# --- Private Subnets ------------------------------------------------------
resource "aws_subnet" "private" {
  count                   = length(var.private_subnet_cidrs)
  vpc_id                  = aws_vpc.custom_vpc.id
  cidr_block              = var.private_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false

  tags = merge(
    var.common_tags,
    { Name = "${var.name}-private-${count.index + 1}" }
  )
}

# --- Security Group -------------------------------------------------------
# Create a Security Group in custom_vpc VPC
resource "aws_security_group" "custom_vpc" {
  name        = var.security_group_name
  description = var.security_group_description
  vpc_id      = aws_vpc.custom_vpc.id

  tags = merge(
    var.common_tags,
    { Name = var.security_group_name }
  )
}

# Ingress rules
resource "aws_security_group_rule" "ingress" {
  for_each = {
    for idx, rule in var.security_group_ingress : idx => rule
  }

  type              = "ingress"
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  protocol          = each.value.protocol
  cidr_blocks       = each.value.cidr_blocks
  description       = each.value.description
  security_group_id = aws_security_group.custom_vpc.id
}

# Egress rules
resource "aws_security_group_rule" "egress" {
  for_each = {
    for idx, rule in var.security_group_egress : idx => rule
  }

  type              = "egress"
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  protocol          = each.value.protocol
  cidr_blocks       = each.value.cidr_blocks
  description       = each.value.description
  security_group_id = aws_security_group.custom_vpc.id
}

