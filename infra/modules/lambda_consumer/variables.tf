variable "queue_arn"     { type = string }
variable "db_url"        { type = string }
variable "db_username"   { type = string }
variable "db_password"   { 
    type = string 
    sensitive = true 
}
variable "aws_region"    { type = string }
variable "source_path"   { type = string }