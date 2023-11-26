terraform {
  required_providers {
    digitalocean = {
      source = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

provider "digitalocean" {
  token = :)
}

variable "pvt_key" {
  default = "~/.ssh/id_rsa"
}

data "digitalocean_ssh_key" "terraform" {
  name = "Maciek OS X"
}