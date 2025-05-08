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
