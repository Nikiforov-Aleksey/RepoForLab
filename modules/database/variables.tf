variable "subnet_id" {
  description = "ID of the subnet for the database"
  type        = string
}

variable "zone" {
  description = "Availability zone"
  type        = string
}

variable "pg_version" {
  description = "PostgreSQL version"
  type        = string
}

variable "db_name" {
  description = "Database name"
  type        = string
}

variable "db_user" {
  description = "Database username"
  type        = string
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "allowed_subnet" {
  description = "Subnet allowed to access the database"
  type        = string
}

variable "ssh_key_path" {
  description = "Path to SSH public key"
  type        = string
}

variable "ssh_private_key_path" {
  description = "Path to SSH private key"
  type        = string
}

variable "security_group_id" {
  description = "Security group ID for database"
  type        = string
}

variable "ip_address" {
  description = "Static internal IP address"
  type        = string
  default     = null
}
