# Database variables for API Gateway and Lambda
variable "db_endpoint" {
  description = "RDS database endpoint"
  type        = string
  default     = "fastfood-db-instance.cn8u9h3oyjdy.us-east-1.rds.amazonaws.com"
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "fastfood"
}

variable "db_username" {
  description = "Database username"
  type        = string
  default     = "fastfood_admin"
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
  default     = "placeholder"
}

variable "jwt_secret" {
  description = "JWT secret key"
  type        = string
  sensitive   = true
  default     = "placeholder"
}

variable "rds_security_group_id" {
  description = "RDS security group ID"
  type        = string
  default     = "sg-033f64c0b844e7b1d"
}
