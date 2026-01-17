terraform {
  backend "s3" {
    bucket         = "opsnote-dev-tfstate"
    key            = "app/terraform.tfstate"
    region         = "ap-northeast-1"
    dynamodb_table = "opsnote-dev-tflock"
    encrypt        = true
  }
}
