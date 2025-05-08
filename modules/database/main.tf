data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2004-lts"
}

resource "yandex_compute_instance" "db" {
  name        = "db-${var.pg_version}"
  platform_id = "standard-v3"
  zone        = var.zone

  resources {
    cores  = 2
    memory = 4
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 20
    }
  }

  network_interface {
    subnet_id          = var.subnet_id
    security_group_ids = [var.security_group_id]
    nat               = true
    ip_address        = var.ip_address
  }

  metadata = {
    ssh-keys = "ubuntu:${file(var.ssh_key_path)}"
    user-data = <<-EOF
      #cloud-config
      package_update: true
      packages:
        - wget
        - gnupg2
        - postgresql-12
        - postgresql-client-12

      write_files:
        - path: /tmp/init-db.sh
          permissions: '0755'
          content: |
            #!/bin/bash
            # Configure PostgreSQL
            curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg
            sudo apt-get update
            sudo systemctl enable postgresql --now

            # Create user and database
            sudo -u postgres psql -c "ALTER USER ${var.db_user} WITH PASSWORD '${var.db_password}';"
            sudo -u postgres psql -c "CREATE DATABASE ${var.db_name};"

            # Update PostgreSQL config
            sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/12/main/postgresql.conf
            echo "host all all ${var.allowed_subnet} md5" | sudo tee -a /etc/postgresql/12/main/pg_hba.conf
            sudo systemctl restart postgresql

      runcmd:
        - /tmp/init-db.sh
        - rm /tmp/init-db.sh
    EOF
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file(var.ssh_private_key_path)
    host        = self.network_interface.0.nat_ip_address
  }

  provisioner "file" {
    source      = "${path.root}/files/data.sql"
    destination = "/tmp/data.sql"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo -u postgres psql ${var.db_name} < /tmp/data.sql",
      "rm /tmp/data.sql"
    ]
  }
}

output "db_host" {
  value = yandex_compute_instance.db.network_interface.0.ip_address
}
