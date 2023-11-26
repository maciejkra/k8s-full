resource "digitalocean_droplet" "cpnode" {
  count              = 3
  name               = "cpnode${count.index + 1}"
  image              = "ubuntu-22-04-x64"
  region             = "fra1"
  size               = "s-2vcpu-4gb"
  tags               = ["control-plane"]
  ssh_keys = [
      data.digitalocean_ssh_key.terraform.id
  ]

  provisioner "remote-exec" {
    inline = [
      "until echo 'Checking if SSH is ready' && exit; do echo 'Waiting for SSH...'; sleep 10; done"
    ]

    connection {
      type        = "ssh"
      host        = self.ipv4_address
      user        = "root"
      private_key = file("~/.ssh/id_rsa")
      timeout     = "2m"
    }
  }

  provisioner "file" {
    content     = file("../prepare.sh")
    destination = "/root/prepare.sh"
    connection {
      type        = "ssh"
      host        = self.ipv4_address
      user        = "root"
      private_key = file("~/.ssh/id_rsa")
    }
  }

  provisioner "file" {
    source      = "../kubeadm-config.yaml"
    destination = "/root/kubeadm-config.yaml"

    connection {
      type        = "ssh"
      host        = self.ipv4_address
      user        = "root"
      private_key = file("~/.ssh/id_rsa")
    }
  }

  provisioner "file" {
    source      = "../kube-vip.sh"
    destination = "/root/kube-vip.sh"

    connection {
      type        = "ssh"
      host        = self.ipv4_address
      user        = "root"
      private_key = file("~/.ssh/id_rsa")
    }
  }

  provisioner "file" {
    source      = "../kubernetes"
    destination = "/etc/"
    connection {
      type        = "ssh"
      host        = self.ipv4_address
      user        = "root"
      private_key = file("~/.ssh/id_rsa")
    }
  }

  provisioner "remote-exec" {
    # Inline script with retry logic
  inline = [
    "sleep 15; sudo bash /root/prepare.sh"
  ]
    
    connection {
      type        = "ssh"
      host        = self.ipv4_address
      user        = "root"
      private_key = file("~/.ssh/id_rsa")
    }
  }

}

resource "digitalocean_droplet" "knode" {
  count              = 3
  name               = "knode${count.index + 1}"
  image              = "ubuntu-22-04-x64"
  region             = "fra1"
  size               = "s-2vcpu-4gb"
  tags               = ["worker"]
  ssh_keys = [
      data.digitalocean_ssh_key.terraform.id
  ]


  provisioner "remote-exec" {
    inline = [
      "until echo 'Checking if SSH is ready' && exit; do echo 'Waiting for SSH...'; sleep 10; done"
    ]

    connection {
      type        = "ssh"
      host        = self.ipv4_address
      user        = "root"
      private_key = file("~/.ssh/id_rsa")
      timeout     = "2m"
    }
  }

  provisioner "file" {
    content     = file("../prepare.sh")
    destination = "/root/prepare.sh"
    connection {
      type        = "ssh"
      host        = self.ipv4_address
      user        = "root"
      private_key = file("~/.ssh/id_rsa")
    }
  }

  provisioner "remote-exec" {
    # Inline script with retry logic
  inline = [
    "sleep 15; sudo bash /root/prepare.sh"
  ]
    
    connection {
      type        = "ssh"
      host        = self.ipv4_address
      user        = "root"
      private_key = file("~/.ssh/id_rsa")
    }
  }
}

resource "null_resource" "hosts_file" {
  # Runs after droplets are created
  depends_on = [digitalocean_droplet.cpnode, digitalocean_droplet.knode]

  provisioner "local-exec" {
    command = <<-EOT
      echo "${digitalocean_droplet.cpnode.*.ipv4_address_private[0]} cpnode1.example.com cpnode1\n\
${digitalocean_droplet.cpnode.*.ipv4_address_private[1]} cpnode2.example.com cpnode2\n\
${digitalocean_droplet.cpnode.*.ipv4_address_private[2]} cpnode3.example.com cpnode3\n\
${digitalocean_droplet.knode.*.ipv4_address_private[0]} knode1.example.com knode1\n\
${digitalocean_droplet.knode.*.ipv4_address_private[1]} knode2.example.com knode2\n\
${digitalocean_droplet.knode.*.ipv4_address_private[2]} knode3.example.com knode3\n\
10.19.0.100 kubeapi.example.com kubeapi" > ../hosts
    EOT
  }
}

output "cpnode_ips" {
  value = digitalocean_droplet.cpnode.*.ipv4_address
}

output "knode_ips" {
  value = digitalocean_droplet.knode.*.ipv4_address
}