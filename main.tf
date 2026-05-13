terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "metabase-tfstate-483921"
    key    = "metabase/terraform.tfstate"
    region = "ap-southeast-1"
  }
}

provider "aws" {
  region = var.aws_region
}

resource "aws_key_pair" "metabase" {
  key_name   = var.key_name
  public_key = var.ssh_public_key
}
