variable "user_name" {
  description = "Name of the IAM user"
  type        = string
}

variable "bucket_arn" {
  description = "ARN of the S3 bucket the user will access"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}
