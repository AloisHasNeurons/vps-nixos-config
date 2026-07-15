terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.117.1"
    }
  }
}

provider "hcloud" {
  token = var.hcloud_token
}

provider "aws" {
  region = var.aws_region
}

provider "azurerm" {
  features {}
}
