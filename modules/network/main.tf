data "yandex_vpc_network" "default" {
  name = "default"
}

data "yandex_vpc_subnet" "default" {
  name = "default-ru-central1-d"
}

resource "yandex_compute_instance" "nat_instance" {
  name        = "nat-instance"
  platform_id = "standard-v3"
  zone        = var.zone

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = var.nat_image_id
      size     = 10
    }
  }

  network_interface {
    subnet_id  = data.yandex_vpc_subnet.default.id
    nat        = true
    ip_address = var.nat_instance_ip
  }

  metadata = {
    ssh-keys = "ubuntu:${file(var.ssh_key_path)}"
  }
}

resource "yandex_vpc_route_table" "nat" {
  name       = "nat-route"
  network_id = data.yandex_vpc_network.default.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    next_hop_address   = yandex_compute_instance.nat_instance.network_interface.0.ip_address
  }
}

output "subnet_id" {
  value = data.yandex_vpc_subnet.default.id
}
