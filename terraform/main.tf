terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  
  endpoints {
    s3  = "http://10.10.2.101:4566"
    ecr = "http://10.10.2.101:4566"
    iam = "http://10.10.2.101:4566"
    sts = "http://10.10.2.101:4566"
  }
}

resource "aws_ecr_repository" "app" {
  name = "devops-project-app"
}

resource "aws_s3_bucket" "artifacts" {
  bucket = "devops-project-artifacts"
}
