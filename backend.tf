terraform {
  backend "s3" {
    bucket = "fiap-mecanica"
    key    = "tfstate/db.tfstate"
    region = "us-east-1"
  }
}
