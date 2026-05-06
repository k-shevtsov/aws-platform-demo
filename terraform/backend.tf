terraform {
  backend "s3" {
    bucket         = "aws-platform-demo-tfstate-658424926455"
    key            = "terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "aws-platform-demo-tfstate-lock"
    encrypt        = true
  }
}
