############################################################
# ADD THIRD PARTY PROVIDERS
############################################################
terraform {
  required_providers {
    intersight = {
      source = "CiscoDevNet/intersight"
      version = "1.0.0"
    }
  }
}

provider "intersight" {
  apikey = var.apikey
  secretkey = var.secretkey
  endpoint = "intersight.com"
}
