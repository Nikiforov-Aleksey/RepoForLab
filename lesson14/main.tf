# Сеть и подсеть
data "yandex_vpc_network" "network" {
  name = "default"
}

data "yandex_vpc_subnet" "subnet" {
  name = "default-ru-central1-d"
}

# Данные об образах
data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2004-lts"
}

# NAT-инстанс для выхода в интернет
resource "yandex_compute_instance" "nat_instance" {
  name        = "nat-instance"
  platform_id = "standard-v3"
  zone        = "ru-central1-d"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = "fd80mrhj8fl2oe87o4e1"
      size     = 10
    }
  }

  network_interface {
    subnet_id  = data.yandex_vpc_subnet.subnet.id
    nat        = true
    ip_address = "10.130.0.21"
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/yandex_cloud_key.pub")}"
  }
}

# Таблица маршрутизации
resource "yandex_vpc_route_table" "nat_route" {
  name       = "nat-route"
  network_id = data.yandex_vpc_network.network.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    next_hop_address   = yandex_compute_instance.nat_instance.network_interface.0.ip_address
  }
}

# ВМ frontend (Nginx)
resource "yandex_compute_instance" "frontend" {
  name        = "frontend"
  platform_id = "standard-v3"
  zone        = "ru-central1-d"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 10
    }
  }

  network_interface {
    subnet_id  = data.yandex_vpc_subnet.subnet.id
    nat        = true
    ip_address = "10.130.0.22"
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/yandex_cloud_key.pub")}"
  }

  provisioner "remote-exec" {
    inline = [
      # Обновление пакетов с обработкой возможных ошибок
      "sudo apt-get update -o Acquire::Check-Valid-Until=false -o Acquire::Retries=3 || true",
      
      # Установка Nginx
      "sudo apt-get install -y nginx",
      
      # Базовая конфигурация Nginx
      "sudo rm -f /etc/nginx/sites-enabled/default",
      "echo 'server {",
      "    listen 80;",
      "    server_name _;",
      "    location / {",
      "        proxy_pass http://${yandex_compute_instance.backend.network_interface.0.ip_address}:8080;",
      "        proxy_set_header Host $host;",
      "        proxy_set_header X-Real-IP $remote_addr;",
      "        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;",
      "    }",
      "}' | sudo tee /etc/nginx/sites-available/digital-library",
      
      # Активация конфигурации
      "sudo ln -s /etc/nginx/sites-available/digital-library /etc/nginx/sites-enabled/",
      
      # Проверка и перезапуск
      "sudo nginx -t",
      "sudo systemctl restart nginx",
      "sudo systemctl enable nginx"
    ]
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/yandex_cloud_key")
      host        = self.network_interface[0].nat_ip_address
      timeout     = "10m"
    }
  }
}
# ВМ backend (Java)
resource "yandex_compute_instance" "backend" {
  name        = "backend"
  platform_id = "standard-v3"
  zone        = "ru-central1-d"

  resources {
    cores  = 4
    memory = 4
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 20
    }
  }

  network_interface {
    subnet_id  = data.yandex_vpc_subnet.subnet.id
    nat        = true
    ip_address = "10.130.0.23"
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/yandex_cloud_key.pub")}"
  }

  # Установка Java и зависимостей
  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update -o Acquire::Check-Valid-Until=false -o Acquire::Retries=5",
      "sudo apt-get install -y openjdk-17-jdk curl",
      "echo 'JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64' | sudo tee -a /etc/environment",
      # Установка firewall и разрешение SSH
      "sudo ufw --force enable",
      "sudo ufw allow OpenSSH"
    ]
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/yandex_cloud_key")
      host        = self.network_interface[0].nat_ip_address
      timeout = "10m"  
   }
  }

  # Копирование JAR-файла
  provisioner "file" {
    source      = "/var/lib/jenkins/workspace/webbooks/apps/webbooks/target/DigitalLibrary-0.0.1-SNAPSHOT.jar"
    destination = "/home/ubuntu/DigitalLibrary.jar"
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/yandex_cloud_key")
      host        = self.network_interface[0].nat_ip_address
    }
  }

  # Создание systemd сервиса
  provisioner "file" {
    content = templatefile("${path.module}/templates/digital-library.service.tftpl", {
      db_ip       = yandex_compute_instance.db.network_interface.0.ip_address
      db_username = "postgres"
      db_password = "password"
      app_port    = "8080"
    })
    destination = "/tmp/digital-library.service"
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/yandex_cloud_key")
      host        = self.network_interface[0].nat_ip_address
    }
  }

  # Настройка и запуск сервиса с проверками
  provisioner "remote-exec" {
    inline = [
      # Настройка сервиса
      "sudo mv /tmp/digital-library.service /etc/systemd/system/",
      "sudo chmod 644 /etc/systemd/system/digital-library.service",
      "sudo systemctl daemon-reload",
      "sudo systemctl enable digital-library",
      
      # Запуск сервиса с проверкой
      "sudo systemctl restart digital-library",
      "sleep 30", # Даем время для полного запуска
      
      # Проверка статуса без блокировки
      "if sudo systemctl is-active --quiet digital-library; then",
      "  echo 'Service started successfully'",
      "else",
      "  echo 'Service failed to start'",
      "  sudo journalctl -u digital-library -n 50 --no-pager",
      "  exit 1",
      "fi",
      
      # Открытие порта приложения
      "sudo ufw allow 8080/tcp"
    ]
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/yandex_cloud_key")
      host        = self.network_interface[0].nat_ip_address
      timeout = "15m"  
   }
  }

  # Проверка работы после деплоя (необязательно)
  provisioner "remote-exec" {
    inline = [
      "echo 'Deployment completed successfully at $(date)' >> /home/ubuntu/deployment.log"
    ]
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/yandex_cloud_key")
      host        = self.network_interface[0].nat_ip_address
    }
    on_failure = continue
  }
}

# ВМ db (PostgreSQL 12)
resource "yandex_compute_instance" "db" {
  name        = "db"
  platform_id = "standard-v3"
  zone        = "ru-central1-d"

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
    subnet_id          = data.yandex_vpc_subnet.subnet.id
    security_group_ids = [data.yandex_vpc_security_group.db_sg.id]
    nat               = true
    ip_address        = "10.130.0.24"
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/yandex_cloud_key.pub")}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update -o Acquire::Check-Valid-Until=false -o Acquire::Retries=5",
      "sudo apt-get install -y wget gnupg2",
      "curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc|sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg",
      "sudo apt-get update",
      "sudo apt-get install -y postgresql-12 postgresql-client-12",
      "sudo systemctl enable postgresql --now",
      "sudo -u postgres psql -c \"ALTER USER postgres WITH PASSWORD 'password'\"",
      "sudo -u postgres psql -c \"CREATE DATABASE webbooks;\"",
      "sudo sed -i \"s/#listen_addresses = 'localhost'/listen_addresses = '*'/\" /etc/postgresql/12/main/postgresql.conf",
      "echo \"host all all 10.130.0.0/24 md5\" | sudo tee -a /etc/postgresql/12/main/pg_hba.conf",
      "sudo systemctl restart postgresql",
      "sleep 5"
    ]
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/yandex_cloud_key")
      host        = self.network_interface[0].nat_ip_address
    }
  }

  # Копируем файл с демо-данными
  provisioner "file" {
    source      = "${path.module}/files/data.sql"
    destination = "/tmp/data.sql"
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/yandex_cloud_key")
      host        = self.network_interface[0].nat_ip_address
    }
  }

  # Загружаем демо-данные
  provisioner "remote-exec" {
    inline = [
      "sudo -u postgres psql webbooks < /tmp/data.sql || echo 'Ошибка загрузки данных, возможно файл отсутствует'",
      "rm -f /tmp/data.sql"
    ]
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/yandex_cloud_key")
      host        = self.network_interface[0].nat_ip_address
    }
  }
}

# Группа безопасности для PostgreSQL
data "yandex_vpc_security_group" "db_sg" {
  name = "default-sg-enpgk3s7om7flad8ml7l"
}

# Outputs
output "frontend_url" {
  value = "http://${yandex_compute_instance.frontend.network_interface.0.nat_ip_address}"
}

output "backend_ssh_command" {
  value = "ssh -i ~/.ssh/yandex_cloud_key ubuntu@${yandex_compute_instance.backend.network_interface.0.nat_ip_address}"
}

output "db_connection" {
  value = {
    host     = yandex_compute_instance.db.network_interface.0.ip_address
    database = "webbooks"
    username = "postgres"
    password = "password"
  }
  sensitive = true
}
