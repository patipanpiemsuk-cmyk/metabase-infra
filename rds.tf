resource "aws_db_instance" "postgres" {
  identifier        = "metabase-postgres"
  engine            = "postgres"
  engine_version    = "15"
  instance_class    = "db.t3.micro"   # Free Tier eligible
  allocated_storage = 20              # GB, Free Tier ได้ 20GB
  storage_type      = "gp2"

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  publicly_accessible = false   # สำคัญมาก! ห้ามเปิด public
  skip_final_snapshot = true    # dev เท่านั้น, prod ตั้งเป็น false

  # prod: เปิด multi_az = true, backup_retention_period = 7
  multi_az                = false
  backup_retention_period = 0

  tags = { Name = "metabase-postgres" }
}