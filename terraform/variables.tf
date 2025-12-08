variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "fitband-broker"
}

variable "instance_type" {
  description = "EC2 instance type (t3.micro is free tier eligible)"
  type        = string
  default     = "t3.micro"
}

variable "key_pair_name" {
  description = "Name of existing AWS key pair for SSH access"
  type        = string
}

variable "ssh_cidr" {
  description = "CIDR block allowed for SSH access"
  type        = string
  default     = "0.0.0.0/0" # Restrict this in production!
}

variable "root_volume_size" {
  description = "Root volume size in GB"
  type        = number
  default     = 20
}

variable "allocate_elastic_ip" {
  description = "Allocate Elastic IP for the instance"
  type        = bool
  default     = true
}

# VPC Configuration
variable "create_vpc" {
  description = "Create new VPC or use default"
  type        = bool
  default     = false
}

variable "vpc_cidr" {
  description = "CIDR block for VPC (if creating new)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

# Database Configuration
variable "use_rds" {
  description = "Use RDS PostgreSQL (true) or install PostgreSQL on EC2 (false - cheaper but less reliable)"
  type        = bool
  default     = true
}

variable "db_instance_class" {
  description = "RDS instance class (db.t3.micro is free tier eligible)"
  type        = string
  default     = "db.t3.micro"
}

variable "db_engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "15.4"
}

variable "db_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 20
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "fitband_broker"
}

variable "db_username" {
  description = "Database master username"
  type        = string
  default     = "postgres"
}

variable "db_password" {
  description = "Database password (leave empty to auto-generate)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "db_skip_final_snapshot" {
  description = "Skip final snapshot when destroying RDS (set to false in production!)"
  type        = bool
  default     = true
}

variable "database_url" {
  description = "Existing database connection URL (use this instead of creating RDS). Format: postgresql://user:pass@host:port/dbname"
  type        = string
  default     = ""
  sensitive   = true
}

# Application Configuration
variable "git_repo_url" {
  description = "Git repository URL for deployment"
  type        = string
}

variable "git_branch" {
  description = "Git branch to deploy"
  type        = string
  default     = "main"
}

variable "api_key" {
  description = "API key for authentication (generate with: openssl rand -hex 32)"
  type        = string
  sensitive   = true
}

variable "cors_origin" {
  description = "CORS allowed origins (comma-separated)"
  type        = string
  default     = "*"
}

