variable "vm_ssh_key" {
  description = "SSH-ключ для доступа к ВМ"
  default     = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINLve+iIQja1Y9DBp6TSd8w9rZcEyhbP/daQxGWMr7wE scyvocer@gmail.com"
}

variable "image_family" {
  description = "Семейство образов для ВМ"
  default = {
    frontend = "lemp"         # LEMP (Nginx + PHP)
    backend  = "ubuntu-2204-lts"
    db       = "ubuntu-2204-lts"
  }
}
variable "db_name" {
  description = "Database name"
  type        = string
  default     = "webbooks"
}

variable "db_user" {
  description = "Database username"
  type        = string
  default     = "postgres"
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
  default     = "password"
}

variable "allowed_subnet" {
  description = "Subnet allowed to access the database"
  type        = string
  default     = "10.130.0.0/24"
}
