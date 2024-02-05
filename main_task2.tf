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

resource "yandex_iam_service_account" "ekarih2" {
  name        = "ekarih2"
  description = "service account to manage IG"
}

resource "yandex_resourcemanager_folder_iam_member" "editor" {
  folder_id = "b1gmlttm66sbucm9033f"
  role      = "editor"
  member    = "serviceAccount:${yandex_iam_service_account.ekarih2.id}"
}

resource "yandex_compute_instance_group" "ig-1" {
  name                = "fixed-ig-with-balancer"
  folder_id           = "b1gmlttm66sbucm9033f"
  service_account_id  = "${yandex_iam_service_account.ekarih2.id}"
  deletion_protection = "true"
  instance_template {
    platform_id = "standard-v3"
    resources {
      core_fraction = 20
      memory = 2
      cores  = 2
    }

    boot_disk {
      mode = "READ_WRITE"
      initialize_params {
        image_id = "fd89iq8mqvli97d9poej"
        size     = 10
      }
    }

    network_interface {
      network_id   = "${yandex_vpc_network.network-1.id}"
      subnet_ids   = ["${yandex_vpc_subnet.subnet-1.id}"]
      nat          = true
    }

    metadata = {
      user-data = "${file("./meta.yml")}"
    }
    
    scheduling_policy {
      preemptible = true
    }
  }

  scale_policy {
    fixed_scale {
      size = 3
    }
  }

  allocation_policy {
    zones = ["ru-central1-a"]
  }

  deploy_policy {
    max_unavailable = 1
    max_expansion   = 0
  }

  load_balancer {
    target_group_name        = "target-group"
    target_group_description = "load balancer target group"
  }
}

resource "yandex_lb_network_load_balancer" "lb-tf" {
  name = "lb-tf"

  listener {
    name = "ekarih-lb"
    port = 80
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_compute_instance_group.ig-1.load_balancer.0.target_group_id

    healthcheck {
      name = "http"
      http_options {
        port = 80
        path = "/"
      }
    }
  }
}

resource "yandex_vpc_network" "network-1" {
  name = "network1"
}

resource "yandex_vpc_subnet" "subnet-1" {
  name           = "subnet1"
  zone           = "ru-central1-a"
  network_id     = "${yandex_vpc_network.network-1.id}"
  v4_cidr_blocks = ["192.168.10.0/24"]
}

output "external_ip_addresses" {
  value = yandex_compute_instance_group.ig-1.instances.*.network_interface.0.nat_ip_address
  }

output "external_ip_address_lb" {
  value = [
    for listener in yandex_lb_network_load_balancer.lb-tf.listener :
    listener.external_address_spec
    ]
  }
