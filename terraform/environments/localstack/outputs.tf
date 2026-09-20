output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnet_id" {
  description = "Public subnet ID"
  value       = module.vpc.public_subnet_id
}

output "security_group_id" {
  description = "Security Group ID"
  value       = module.security_group.security_group_id
}

output "s3_bucket_id" {
  description = "S3 bucket name"
  value       = module.s3.bucket_id
}

output "iam_user_name" {
  description = "IAM user name"
  value       = module.iam.user_name
}
