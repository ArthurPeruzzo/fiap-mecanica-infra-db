variable "project_name" {
  default = "fiap-mecanica"
}

variable "region_default" {
  default = "us-east-1"
}

variable "tags" {
  default = {
    Name = "fiap-mecanica-terraform"
  }
}

variable "db_name" {
  description = "Initial database name created on the RDS instance"
  default     = "mecanica"
}

variable "db_instance_class" {
  description = "RDS instance class"
  default     = "db.t3.micro"
}

variable "db_username" {
  description = "Master username for the RDS MySQL instance"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Master password for the RDS MySQL instance"
  type        = string
  sensitive   = true
}
