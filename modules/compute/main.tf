data "yandex_compute_image" "vm_image" {
  family = var.image_family
}

resource "yandex_compute_instance" "vm" {
  name        = var.name
  platform_id = "standard-v3"
  zone        = var.zone

  resources {
    cores  = var.cores
    memory = var.memory
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.vm_image.id
      size     = var.disk_size
    }
  }

  network_interface {
    subnet_id = var.subnet_id
    nat       = var.nat
    ip_address = var.ip_address
  }

  metadata = {
    ssh-keys = "ubuntu:${file(var.ssh_key_path)}"
    user-data = var.user_data
  }
}

output "internal_ip" {
  value = yandex_compute_instance.vm.network_interface.0.ip_address
}

output "external_ip" {
  value = yandex_compute_instance.vm.network_interface.0.nat_ip_address
}
