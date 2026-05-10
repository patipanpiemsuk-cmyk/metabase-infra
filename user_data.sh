#!/bin/bash
set -e

# อัพเดท OS
yum update -y

# ติดตั้ง Docker
amazon-linux-extras install docker -y
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# ดึง DB password จาก SSM Parameter Store
DB_PASSWORD=$(aws ssm get-parameter \
  --name "/metabase/db_password" \
  --with-decryption \
  --query "Parameter.Value" \
  --output text \
  --region ap-southeast-1)

# รัน Metabase ด้วย Docker
docker run -d \
  --name metabase \
  --restart unless-stopped \
  -p 3000:3000 \
  -e MB_DB_TYPE=postgres \
  -e MB_DB_DBNAME=${db_name} \
  -e MB_DB_PORT=5432 \
  -e MB_DB_USER=${db_user} \
  -e MB_DB_PASS="$DB_PASSWORD" \
  -e MB_DB_HOST=${db_host} \
  metabase/metabase:latest

echo "Metabase started!"