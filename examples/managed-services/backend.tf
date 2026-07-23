terraform {
  backend "s3" {
    key = "managed-services/terraform.tfstate"
  }
}
