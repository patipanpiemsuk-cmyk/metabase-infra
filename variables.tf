variable "aws_region" {
  default = "ap-southeast-1"
}

variable "db_name" {
  default = "metabase"
}

variable "db_username" {
  default = "metabase_user"
}

variable "db_password" {
  description = "PostgreSQL password - ห้าม hardcode ใน code จริง"
  sensitive   = true
}

variable "key_name" {
  description = "ชื่อ SSH Key Pair ใน AWS"
  default     = "metabase-key"
}

variable "allowed_cidr" {
  description = "IP ที่อนุญาตเข้า port 3000"
  default     = "0.0.0.0/0"
}