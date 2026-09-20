resource "aws_iam_user" "this" {
  name = var.user_name

  tags = {
    Project     = "aws-iac-monitoring-stack"
    ManagedBy   = "terraform"
    Environment = var.environment
  }
}

resource "aws_iam_policy" "this" {
  name        = "${var.user_name}-policy"
  description = "Policy for ${var.user_name} to access S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          var.bucket_arn,
          "${var.bucket_arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_user_policy_attachment" "this" {
  user       = aws_iam_user.this.name
  policy_arn = aws_iam_policy.this.arn
}
