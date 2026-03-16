terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state — swap in your actual bucket name
  backend "s3" {
    bucket = "supportdesk-tfstate-vm"
    key    = "phase1/terraform.tfstate"
    region = "eu-west-1"
  }
}

provider "aws" {
  region = var.aws_region
}

# ── VPC ────────────────────────────────────────────────────────────────────────
# We're building the network from scratch so the repo is fully self-contained.
# A VPC is your private network inside AWS — nothing gets in or out unless
# you explicitly allow it.

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"   # 65,536 private IP addresses
  enable_dns_hostnames = true             # RDS needs this to generate its endpoint hostname

  tags = { Name = "supportdesk-vpc" }
}

# Two private subnets in different availability zones.
# RDS requires subnets in at least 2 AZs even for single-AZ deployments.
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"    # 256 addresses
  availability_zone = "${var.aws_region}a"

  tags = { Name = "supportdesk-private-a" }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.aws_region}b"

  tags = { Name = "supportdesk-private-b" }
}

# One public subnet — this is where your app (Spring Boot) will eventually live,
# behind a load balancer. For Phase 1, your app runs locally but connects to RDS
# over a bastion or SSM. More on that below.
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.10.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = { Name = "supportdesk-public-a" }
}

# Internet Gateway — gives the public subnet a route to the internet
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "supportdesk-igw" }
}

# Route table for the public subnet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "supportdesk-public-rt" }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

# ── Security group for the app ─────────────────────────────────────────────────
# Even though Spring Boot runs locally in Phase 1, we declare this security
# group now so the database module can reference it. In Phase 2 this group
# will be attached to an EC2 instance or ECS task.

resource "aws_security_group" "app" {
  name   = "supportdesk-app-sg"
  vpc_id = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "supportdesk-app-sg" }
}

# ── Database module ────────────────────────────────────────────────────────────
module "database" {
  source = "./modules/database"

  db_name               = var.db_name
  db_username           = var.db_username
  db_password           = var.db_password
  vpc_id                = aws_vpc.main.id
  subnet_ids            = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  app_security_group_id = aws_security_group.app.id
}