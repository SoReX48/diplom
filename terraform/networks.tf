# VPC network 

resource "yandex_vpc_network" "network1" {
  name = "network1"

}

# NAT-шлюз, статический маршрут через Bastion для внутренней сети

resource "yandex_vpc_gateway" "nat_gateway" {
  name = "nat-gateway"
  shared_egress_gateway {}
}

resource "yandex_vpc_route_table" "route_table" {
  network_id = yandex_vpc_network.network1.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.nat_gateway.id
  }
}


# Подсеть для ВМ с nginx1 (приватная подсеть)

resource "yandex_vpc_subnet" "private-nginx1" {
  name = "private-nginx1"

  v4_cidr_blocks = ["192.168.1.0/24"]
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network1.id
  route_table_id = yandex_vpc_route_table.route_table.id

}

# Подсеть для ВМ с nginx2 (приватная подсеть)

resource "yandex_vpc_subnet" "private-nginx2" {
  name = "private-nginx2"

  v4_cidr_blocks = ["192.168.2.0/24"]
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.network1.id
  route_table_id = yandex_vpc_route_table.route_table.id
}

# Подсеть для сервисов (приватная подсеть)

resource "yandex_vpc_subnet" "private-services" {
  name = "private-services"

  v4_cidr_blocks = ["192.168.3.0/24"]
  zone           = "ru-central1-d"
  network_id     = yandex_vpc_network.network1.id
  route_table_id = yandex_vpc_route_table.route_table.id
}

# Подсеть для Bastion (публичная подсеть)

resource "yandex_vpc_subnet" "public-subnet" {
  name = "public-subnet"

  v4_cidr_blocks = ["192.168.4.0/24"]
  zone           = "ru-central1-d"
  network_id     = yandex_vpc_network.network1.id
}


# Target Groups 

resource "yandex_alb_target_group" "tg-group" {
  name = "tg-group"

  target {
    ip_address = yandex_compute_instance.nginx1.network_interface.0.ip_address
    subnet_id  = yandex_vpc_subnet.private-nginx1.id
  }

  target {
    ip_address = yandex_compute_instance.nginx2.network_interface.0.ip_address
    subnet_id  = yandex_vpc_subnet.private-nginx2.id
  }
}

# Backend Group    

resource "yandex_alb_backend_group" "backend-group" {
  name = "backend-group"

  http_backend {
    name             = "backend"
    weight           = 1
    port             = 80
    target_group_ids = [yandex_alb_target_group.tg-group.id]
    load_balancing_config {
      panic_threshold = 90
    }
    healthcheck {
      timeout             = "10s"
      interval            = "2s"
      healthy_threshold   = 10
      unhealthy_threshold = 15
      http_healthcheck {
        path = "/"
      }
    }
  }
}

resource "yandex_alb_http_router" "router" {
  name = "router"
}

resource "yandex_alb_virtual_host" "router-host" {
  name           = "router-host"
  http_router_id = yandex_alb_http_router.router.id
  route {
    name = "route"
    http_route {
      http_match {
        path {
          prefix = "/"
        }
      }
      http_route_action {
        backend_group_id = yandex_alb_backend_group.backend-group.id
        timeout          = "3s"
      }
    }
  }
}

resource "yandex_alb_load_balancer" "load-balancer" {
  name               = "load-balancer"
  network_id         = yandex_vpc_network.network1.id
  security_group_ids = [yandex_vpc_security_group.load-balancer-sg.id, yandex_vpc_security_group.private-sg.id]

  allocation_policy {
    location {
      zone_id   = "ru-central1-d"
      subnet_id = yandex_vpc_subnet.private-services.id
    }
  }

  listener {
    name = "listener-1"
    endpoint {
      address {
        external_ipv4_address {
        }
      }
      ports = [80]
    }
    http {
      handler {
        http_router_id = yandex_alb_http_router.router.id
      }
    }
  }
}

# Security Groups  

resource "yandex_vpc_security_group" "private-sg" {
  name       = "private-sg"
  network_id = yandex_vpc_network.network1.id

  ingress {
    protocol = "TCP"

    predefined_target = "loadbalancer_healthchecks"
    from_port         = 0
    to_port           = 65535
  }

  ingress {
    protocol       = "ANY"
    from_port         = 0
    to_port           = 65535
    v4_cidr_blocks = ["192.168.1.0/24", "192.168.2.0/24", "192.168.3.0/24", "192.168.4.0/24"]
  }

  egress {
    protocol       = "ANY"
    from_port         = 0
    to_port           = 65535
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "yandex_vpc_security_group" "load-balancer-sg" {
  name       = "load-balancer-sg"
  network_id = yandex_vpc_network.network1.id

  ingress {
    protocol          = "ANY"
    v4_cidr_blocks    = ["0.0.0.0/0"]
    predefined_target = "loadbalancer_healthchecks"
  }

  ingress {
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 80
  }

  ingress {
    protocol       = "ICMP"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "bastion-sg" {
  name       = "bastion-sg"
  network_id = yandex_vpc_network.network1.id

  ingress {
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 22
  }

  ingress {
    protocol       = "ICMP"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol       = "ANY"
    from_port         = 0
    to_port           = 65535
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}



resource "yandex_vpc_security_group" "kibana-sg" {
  name       = "kibana-sg"
  network_id = yandex_vpc_network.network1.id

  ingress {
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 5601
  }

  ingress {
    protocol       = "ICMP"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "zabbix-sg" {
  name       = "zabbix-sg"
  network_id = yandex_vpc_network.network1.id

  ingress {
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 8080
  }

  ingress {
    protocol       = "ICMP"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol       = "ANY"
    from_port         = 0
    to_port           = 65535
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "yandex_vpc_security_group" "elasticsearch-sg" {
  name        = "elasticsearch-sg"
  description = "Elasticsearch security group"
  network_id  = yandex_vpc_network.network1.id

  ingress {
    protocol          = "TCP"
    security_group_id = yandex_vpc_security_group.kibana-sg.id
    port              = 9200
  }

  ingress {
    protocol          = "TCP"
    description       = "Rule for web"
    security_group_id = yandex_vpc_security_group.private-sg.id
    port              = 9200
  }

  ingress {
    protocol          = "TCP"
    description       = "Rule for bastion ssh"
    security_group_id = yandex_vpc_security_group.bastion-sg.id
    port              = 22
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}
