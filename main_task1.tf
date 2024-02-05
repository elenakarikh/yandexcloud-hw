terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

variable "yandex_cloud_token" {
  type = string
}

provider "yandex" {
  token     = var.yandex_cloud_token
  cloud_id  = "b1gpv6u3h36g7impb908"
  folder_id = "b1gmlttm66sbucm9033f"
  zone      = "ru-central1-b"
}

resource "yandex_compute_instance" "vm" {
  count         = 2  
  name          = "vm${count.index}"
  platform_id   = "standard-v3"

  resources {
    core_fraction = 20 
    cores         = 2
    memory        = 2
  }
  
  scheduling_policy {
    preemptible = true
  }
  
  boot_disk {
    initialize_params {
      image_id = "fd89iq8mqvli97d9poej"
      size     = 10
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-1.id
    nat       = true
  }

  metadata = {
    user-data = "${file("./meta.yml")}"
  }
}

resource "yandex_vpc_network" "network-1" {
  name = "network1"
}

resource "yandex_vpc_subnet" "subnet-1" {
  name           = "subnet1"
  zone           = "ru-central1-b"
  network_id     = "${yandex_vpc_network.network-1.id}"
  v4_cidr_blocks = ["192.168.10.0/24"]
}

resource "yandex_lb_network_load_balancer" "lb-tf" {
  name = "lb-tf"
  deletion_protection = "false"
  listener {
    name = "ekarih-lb"
    port = 80
    external_address_spec {
      ip_version = "ipv4"
      }
    }
    attached_target_group {
      target_group_id = yandex_lb_target_group.test-tf.id
      healthcheck {
        name = "http"
        http_options {
          port = 80
          path = "/"
          }
        }
    }
}

resource "yandex_lb_target_group" "test-tf" {
  name = "test-tf"
  target {
    subnet_id = yandex_vpc_subnet.subnet-1.id
    address = yandex_compute_instance.vm[0].network_interface.0.ip_address
    }
  target {
    subnet_id = yandex_vpc_subnet.subnet-1.id
    address = yandex_compute_instance.vm[1].network_interface.0.ip_address
    }
}

