# SG สำหรับ EC2 (Metabase)
resource "aws_security_group" "metabase" {
  name        = "metabase-sg"
  description = "Security group for Metabase EC2"
  vpc_id      = aws_vpc.main.id

  # HTTP (ใน prod ใช้ ALB + HTTPS แทน)
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
    description = "Metabase web port"
  }

  # SSH (ใน prod ใช้ AWS Systems Manager Session Manager แทน)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
    description = "SSH access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "metabase-sg" }
}

# SG สำหรับ RDS (ยอมให้แค่ EC2 เชื่อมต่อเท่านั้น)
resource "aws_security_group" "rds" {
  name        = "metabase-rds-sg"
  description = "Security group for RDS PostgreSQL"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.metabase.id]
    description     = "PostgreSQL from Metabase EC2 only"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "metabase-rds-sg" }
}