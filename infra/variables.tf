variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "eu-west-1"
}

variable "db_name" {
  type    = string
  default = "supportdesk"
}

variable "db_username" {
  type    = string
  default = "supportdesk_admin"
}

variable "db_password" {
  type      = string
  sensitive = true
  # No default — this must be passed in explicitly. Never commit a password.
}