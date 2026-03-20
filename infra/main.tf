terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
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
  cidr_block           = "10.0.0.0/16" # 65,536 private IP addresses
  enable_dns_hostnames = true          # RDS needs this to generate its endpoint hostname

  tags = { Name = "supportdesk-vpc" }
}

# One public subnet — RDS lives here (publicly accessible, SG locked to your IP)
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.10.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = { Name = "supportdesk-public-a" }
}

# Second subnet in a different AZ — RDS subnet group requires at least two
resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.11.0/24"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true
  tags                    = { Name = "supportdesk-public-b" }
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

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# ── Modules ────────────────────────────────────────────────────────────
module "database" {
  source      = "./modules/database"
  db_name     = var.db_name
  db_username = var.db_username
  db_password = var.db_password
  vpc_id      = aws_vpc.main.id
  subnet_ids  = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}

module "lambda" {
  source                  = "./modules/lambda"
  db_url                  = module.database.db_endpoint
  db_username             = var.db_username
  db_password             = var.db_password
  aws_region              = var.aws_region
  jar_path                = "../backend/supportdesk/target/supportdesk-0.0.1-SNAPSHOT-aws.jar"
  allowed_origins         = module.frontend.cloudfront_url
  sqs_queue_url           = module.sqs.queue_url
  sqs_queue_arn           = module.sqs.queue_arn
  attachments_bucket_name = module.attachments.bucket_name
  attachments_bucket_arn  = module.attachments.bucket_arn
}

module "api_gateway" {
  source               = "./modules/api_gateway"
  lambda_invoke_arn    = module.lambda.invoke_arn
  lambda_function_name = module.lambda.function_name
  aws_region           = var.aws_region
  allowed_origins      = module.frontend.cloudfront_url
}

module "frontend" {
  source = "./modules/frontend"
}

module "sqs" {
  source = "./modules/sqs"
}

module "attachments" {
  source          = "./modules/attachments"
  allowed_origins = module.frontend.cloudfront_url
}

module "lambda_consumer" {
  source      = "./modules/lambda_consumer"
  queue_arn   = module.sqs.queue_arn
  db_url      = module.database.db_endpoint
  db_username = var.db_username
  db_password = var.db_password
  aws_region  = var.aws_region
  source_path = "../consumer"
}