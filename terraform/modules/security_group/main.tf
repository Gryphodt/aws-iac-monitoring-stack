resource "aws_security_group" "this" {
  name        = "${var.environment}-sg"
  description = "Security group for ${var.environment} environment"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH from private network"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.private_cidr]
  }

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.environment}-sg"
    Project     = "aws-iac-monitoring-stack"
    ManagedBy   = "terraform"
    Environment = var.environment
  }
}
