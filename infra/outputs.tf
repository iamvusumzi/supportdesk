output "db_endpoint" {
  description = "Pass this to Spring Boot as SPRING_DATASOURCE_URL"
  value       = module.database.db_endpoint
}

output "vpc_id" {
  value = aws_vpc.main.id
}