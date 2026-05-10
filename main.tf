terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # สำหรับ prod ใช้ S3 backend แทน local state
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "metabase/terraform.tfstate"
  #   region         = "ap-southeast-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-locks"
  # }
}

provider "aws" {
  region = var.aws_region
}

# Upload SSH public key ไปยัง AWS
# resource "aws_key_pair" "metabase" {
#   key_name   = var.key_name
#   public_key = file("~/.ssh/metabase-key.pub")
# }
resource "aws_key_pair" "metabase" {
  key_name   = var.key_name
  public_key = var.ssh_public_key
}