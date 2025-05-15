# # // outputs.tf in the same folder as main.tf

output "rds_endpoint" {
  description = "RDS endpoint (host name)"
  value       = aws_db_instance.postgres.address
}

output "rds_port" {
  description = "RDS listener port"
  value       = aws_db_instance.postgres.port
}

output "db_username" {
  description = "Master DB username"
  value       = var.db_username
}

output "db_name" {
  description = "Initial database name"
  value       = var.db_name
}

output "db_password" {
  description = "Master DB password"
  value       = var.db_password
  sensitive   = true
}
