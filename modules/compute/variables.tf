variable "name" {
  description = "Name of the VM instance"
  type        = string
}

variable "cores" {
  description = "Number of CPU cores"
  type        = number
}

variable "memory" {
  description = "Amount of memory in GB"
  type        = number
}

variable "disk_size" {
  description = "Size of the boot disk in GB"
  type        = number
}

variable "image_family" {
  description = "Family of the OS image"
  type        = string
}

variable "subnet_id" {
  description = "ID of the subnet where the VM will be created"
  type        = string
}

variable "zone" {
  description = "Availability zone"
  type        = string
}

variable "nat" {
  description = "Enable NAT for the VM"
  type        = bool
  default     = false
}

variable "ssh_key_path" {
  description = "Path to the SSH public key"
  type        = string
}

variable "ip_address" {
  description = "Static internal IP address"
  type        = string
  default     = null
}

variable "user_data" {
  description = "Cloud-init configuration"
  type        = string
  default     = ""
}
