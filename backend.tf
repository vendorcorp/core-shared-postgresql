terraform {
  backend "s3" {
    bucket         = "vendorcorp-platform-core"
    key            = "terraform-state/core-shared-postgresql"
    dynamodb_table = "vendorcorp-terraform-state-lock"
    region         = "us-east-2"
  }
}
