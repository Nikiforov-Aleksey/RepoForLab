terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"

}

provider "yandex" {
  zone = "ru-central1-d"
service_account_key_file = "/home/naa/key.json"
folder_id   = "b1g252e6u1llb1mutq7n"
}

# Модуль сети
module "network" {
  source        = "./modules/network"
  zone          = "ru-central1-d"
  ssh_key_path  = "~/.ssh/yandex_cloud_key.pub"
  nat_image_id  = "fd80mrhj8fl2oe87o4e1"
  nat_instance_ip = "10.130.0.21"
}

# Модуль базы данных
module "db" {
  source          = "./modules/database"
  subnet_id       = module.network.subnet_id
  zone            = "ru-central1-d"
  pg_version      = "12"
  db_name         = "webbooks"
  db_user         = "postgres"
  db_password     = "password"
  allowed_subnet  = "10.130.0.0/24"
  ssh_key_path    = "~/.ssh/yandex_cloud_key.pub"
  ssh_private_key_path = "~/.ssh/yandex_cloud_key"
  security_group_id = data.yandex_vpc_security_group.db_sg.id
  ip_address      = "10.130.0.24"
}

# Модуль backend (Java приложение)
module "backend" {
  source        = "./modules/compute"
  name          = "backend"
  cores         = 4
  memory        = 4
  disk_size     = 20
  image_family  = "ubuntu-2004-lts"
  subnet_id     = module.network.subnet_id
  zone          = "ru-central1-d"
  nat           = true
  ssh_key_path  = "~/.ssh/yandex_cloud_key.pub"
  ip_address    = "10.130.0.23"
  
  user_data = templatefile("${path.module}/templates/backend-cloud-init.yaml", {
    db_host     = module.db.db_host
    db_user     = "postgres"
    db_password = "password"
    app_port    = "8080"
  })
}

# Модуль frontend (Nginx)
module "frontend" {
  source        = "./modules/compute"
  name          = "frontend"
  cores         = 2
  memory        = 2
  disk_size     = 10
  image_family  = "ubuntu-2004-lts"
  subnet_id     = module.network.subnet_id
  zone          = "ru-central1-d"
  nat           = true
  ssh_key_path  = "~/.ssh/yandex_cloud_key.pub"
  ip_address    = "10.130.0.22"
  
  user_data = templatefile("${path.module}/templates/frontend-cloud-init.yaml", {
    backend_ip = module.backend.internal_ip
  })
}

# Группа безопасности для БД
data "yandex_vpc_security_group" "db_sg" {
  name = "default-sg-enpgk3s7om7flad8ml7l"
}

# Outputs
output "frontend_url" {
  value = "http://${module.frontend.external_ip}"
}

output "backend_app_url" {
  value = "http://${module.backend.external_ip}:8080"
}

output "backend_ssh_command" {
  value = "ssh -i ~/.ssh/yandex_cloud_key ubuntu@${module.backend.external_ip}"
}

output "frontend_ssh_command" {
  value = "ssh -i ~/.ssh/yandex_cloud_key ubuntu@${module.frontend.external_ip}"
}

output "db_connection" {
  value = {
    host     = module.db.db_host
    database = "webbooks"
    username = "postgres"
    password = "password"
  }
  sensitive = true
}
resource "null_resource" "copy_jar" {
  depends_on = [module.backend]

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("~/.ssh/yandex_cloud_key")
    host        = module.backend.external_ip
  }

  provisioner "file" {
    source      = "/var/lib/jenkins/workspace/webbooks/apps/webbooks/target/DigitalLibrary-0.0.1-SNAPSHOT.jar"
    destination = "/home/ubuntu/DigitalLibrary-0.0.1-SNAPSHOT.jar"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/ubuntu/DigitalLibrary-0.0.1-SNAPSHOT.jar",
      "chown ubuntu:ubuntu /home/ubuntu/DigitalLibrary-0.0.1-SNAPSHOT.jar",
      "sudo systemctl restart digital-library"
    ]
  }
}
