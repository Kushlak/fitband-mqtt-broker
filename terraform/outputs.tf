output "ec2_instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.app.id
}

output "ec2_public_ip" {
  description = "EC2 public IP address"
  value       = var.allocate_elastic_ip ? aws_eip.app[0].public_ip : aws_instance.app.public_ip
}

output "ec2_public_dns" {
  description = "EC2 public DNS name"
  value       = aws_instance.app.public_dns
}

output "rds_endpoint" {
  description = "RDS endpoint (if using RDS)"
  value       = var.database_url != "" ? "Using existing database" : (var.use_rds ? aws_db_instance.postgres[0].endpoint : "PostgreSQL running on EC2")
}

output "rds_port" {
  description = "RDS port"
  value       = var.database_url != "" ? "N/A (using existing database)" : (var.use_rds ? aws_db_instance.postgres[0].port : 5432)
}

output "database_url" {
  description = "Database connection URL (sensitive)"
  value       = var.database_url != "" ? var.database_url : (var.use_rds ? "postgresql://${var.db_username}:${var.db_password != "" ? var.db_password : random_password.db_password.result}@${aws_db_instance.postgres[0].endpoint}/${var.db_name}" : "postgresql://postgres:postgres@localhost:5432/${var.db_name}")
  sensitive   = true
}

output "application_urls" {
  description = "Application access URLs"
  value = {
    health    = "http://${var.allocate_elastic_ip ? aws_eip.app[0].public_ip : aws_instance.app.public_ip}:8080/health"
    api       = "http://${var.allocate_elastic_ip ? aws_eip.app[0].public_ip : aws_instance.app.public_ip}:8080/api"
    websocket = "ws://${var.allocate_elastic_ip ? aws_eip.app[0].public_ip : aws_instance.app.public_ip}:8080/ws"
  }
}

output "ssh_command" {
  description = "SSH command to connect to instance"
  value       = "ssh -i ~/.ssh/${var.key_pair_name}.pem ubuntu@${var.allocate_elastic_ip ? aws_eip.app[0].public_ip : aws_instance.app.public_ip}"
}

output "deployment_instructions" {
  description = "Instructions for deploying updates"
  value = <<-EOT
    To deploy updates:
    1. SSH to the instance: ${aws_instance.app.public_ip != "" ? "ssh -i ~/.ssh/${var.key_pair_name}.pem ubuntu@${var.allocate_elastic_ip ? aws_eip.app[0].public_ip : aws_instance.app.public_ip}" : "See ssh_command output"}
    2. Run: cd /home/ubuntu/fitband-mqtt-broker && git pull origin ${var.git_branch}
    3. Run: sudo docker-compose -f docker-compose.prod.yml --env-file .env.prod up -d --build
  EOT
}

