module "vpc" {
  source = "../../modules/vpc"

  vpc_cidr           = "10.0.0.0/16"
  public_subnet_cidr = "10.0.1.0/24"
  environment        = var.environment
}

module "security_group" {
  source = "../../modules/security_group"

  vpc_id       = module.vpc.vpc_id
  private_cidr = "192.168.56.0/24"
  environment  = var.environment
}

module "s3" {
  source = "../../modules/s3"

  bucket_name = "${var.environment}-iac-monitoring-backups"
  environment = var.environment
}

module "iam" {
  source = "../../modules/iam"

  user_name   = "${var.environment}-backup-user"
  bucket_arn  = module.s3.bucket_arn
  environment = var.environment
}
