output "frontend_url" {
  description = "Open this in your browser once deployed"
  value       = module.frontend.cloudfront_url
}

output "api_endpoint" {
  description = "Pass this as VITE_API_URL when building the frontend"
  value       = module.api_gateway.api_endpoint
}

output "s3_bucket_name" {
  value = module.frontend.s3_bucket_name
}

output "cloudfront_id" {
  value = module.frontend.cloudfront_id
}

output "db_endpoint" {
  value = module.database.db_endpoint
}