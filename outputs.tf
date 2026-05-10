output "metabase_url" {
  description = "URL เข้า Metabase"
  value       = "http://${aws_instance.metabase.public_ip}:3000"
}

output "ec2_public_ip" {
  value = aws_instance.metabase.public_ip
}

output "rds_endpoint" {
  description = "RDS endpoint (private, เข้าได้แค่จาก EC2)"
  value       = aws_db_instance.postgres.address
}