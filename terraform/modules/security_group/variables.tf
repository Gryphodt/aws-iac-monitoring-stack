variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "private_cidr" {
  description = "CIDR for private SSH access"
  type        = string
  default     = "192.168.56.0/24"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}
