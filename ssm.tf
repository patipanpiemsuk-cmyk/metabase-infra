# เก็บ DB password ใน SSM Parameter Store (encrypted)
resource "aws_ssm_parameter" "db_password" {
  name        = "/metabase/db_password"
  description = "Metabase database password"
  type        = "SecureString"  # เข้ารหัสด้วย KMS อัตโนมัติ
  value       = var.db_password

  tags = { Name = "metabase-db-password" }
}

# prod: ใช้ AWS Secrets Manager แทน SSM ถ้าต้องการ rotate อัตโนมัติ