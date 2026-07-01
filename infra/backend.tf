terraform {
  backend "s3" {
    bucket = "hamza-gatus-tfstate"
    key    = "terraform.tfstate"
    region = "eu-west-2"
  }
}
