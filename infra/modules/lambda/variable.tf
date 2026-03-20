variable "db_url"      { type = string }
variable "db_username" { type = string }
variable "db_password" {
  type      = string
  sensitive = true
}
variable "aws_region"  { type = string }
variable "jar_path"    { type = string }
variable "allowed_origins" { type = string }
variable "sqs_queue_url" { type = string }
variable "sqs_queue_arn" { type = string }
variable "attachments_bucket_name" { type = string }
variable "attachments_bucket_arn"  { type = string }