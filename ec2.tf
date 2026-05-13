# ดึง AMI Amazon Linux 2 ล่าสุด
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# IAM Role สำหรับ EC2 เพื่อดึง SSM secrets
resource "aws_iam_role" "ec2_role" {
  name = "metabase-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "ssm_read" {
  name = "ssm-read-policy"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ssm:GetParameter"]
      Resource = [aws_ssm_parameter.db_password.arn]
    }]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "metabase-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# EC2 Instance
resource "aws_instance" "metabase" {
  ami = data.aws_ami.amazon_linux.id
  #instance_type          = "t2.micro"   # Free Tier
  instance_type          = "t3.small" # เสียเงิน 15 บาท / วัน
  key_name               = aws_key_pair.metabase.key_name
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.metabase.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  # Template user_data ใส่ค่า db host/name/user ลงไป
  user_data = templatefile("${path.module}/user_data.sh", {
    db_host = aws_db_instance.postgres.address
    db_name = var.db_name
    db_user = var.db_username
  })

  tags = { Name = "metabase-server" }

  # รอให้ RDS พร้อมก่อน
  depends_on = [aws_db_instance.postgres]
}