variable "db_name" {
  description = "Name of the database to create"
  type        = string
}

variable "db_username" {
  description = "Master username for the RDS instance"
  type        = string
}

variable "db_password" {
  description = "Master password - never hardcode this, pass it in"
  type        = string
  sensitive   = true   # Terraform won't print this in logs
}

variable "vpc_id" {
  description = "The VPC this database will live inside"
  type        = string
}

variable "subnet_ids" {
  description = "Public subnets the RDS instance can be placed in"
  type        = list(string)
}
