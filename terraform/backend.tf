terraform {
  backend "s3" {
    bucket = "wolke7-terraform-s3"
    key    = "state.tfstate"
  }
}