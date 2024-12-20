terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  // this is a temporary state backend for development. There will be no need to include this in the blog.
  backend "s3" {
    bucket  = "guardrails-cw-metrics-tf"
    region  = "us-west-2"
    key     = "terraform.tfstate"
    profile = "bedrock-guardrails-cw-metrics"
  }
}

# Configure the AWS Provider
provider "aws" {
  region  = var.aws_region
  profile = "bedrock-guardrails-cw-metrics"
}


data "aws_caller_identity" "current" {}
