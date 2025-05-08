variable "zone" {
  description = "Availability zone"
  type        = string
}

variable "ssh_key_path" {
  description = "Path to SSH public key"
  type        = string
}

variable "nat_image_id" {
  description = "ID of NAT instance image"
  type        = string
  default     = "fd80mrhj8fl2oe87o4e1"
}

variable "nat_instance_ip" {
  description = "IP address for NAT instance"
  type        = string
  default     = "10.130.0.21"
}
