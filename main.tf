terraform {
    required_providers {
      google = {
        source = "hashicorp/google"
      }
    }
  }

# PROVIDER
provider "google" {
    project = "asg-workshop"
    region = "${var.region}"
    zone = "${var.zone}"
    credentials = "${var.GOOGLE_CREDENTIALS}"
}

# NETWORK
resource "google_compute_network" "net" {
    name = "net"
    auto_create_subnetworks = false
}

# SUBNETS
resource "google_compute_subnetwork" "public1" {
    name = "public1"
    network = google_compute_network.net.self_link
    region = "${var.region}"
    ip_cidr_range = "10.0.1.0/29"
}

resource "google_compute_subnetwork" "private1" {
    name = "private1"
    network = google_compute_network.net.self_link
    region = "${var.region}"
    ip_cidr_range = "10.0.3.0/29"  
}

# ROUTER
resource "google_compute_router" "router"{
    name = "router"
    region = "${var.region}"
    network = google_compute_network.net.self_link

    depends_on = [ google_compute_network.net ]
}

 # ROUTER NAT
resource "google_compute_router_nat" "nat" {
    name = "nat"
    source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
    router = google_compute_router.router.name
    nat_ip_allocate_option = "AUTO_ONLY"

    subnetwork {
      name = google_compute_subnetwork.private1.name
      source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
    }
    
    depends_on = [google_compute_router.router]
}

#FIREWALL
resource "google_compute_firewall" "allow-ingress" {
  name = "allow-ingress"
  network = google_compute_network.net.self_link
  direction = "INGRESS"

  allow {
    protocol = "tcp"
    ports = ["22"]
  }

  allow {
    protocol = "udp"
    ports = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow-egress" {
  name = "allow-egress"
  network = google_compute_network.net.self_link
  direction = "EGRESS"

  allow {
    protocol = "tcp"
    ports = ["22"]
  }

  allow {
    protocol = "udp"
    ports = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow-ssh-iap-tunnel" {
  name = "allow-ssh-iap-tunnel"
  network = google_compute_network.net.self_link
  direction = "INGRESS"

  allow {
    protocol = "tcp"
    ports = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]
  target_tags = ["iap-tunnel"]
}

# PUBLIC INSTANCE
resource "google_compute_instance" "public-vm" {
  name = "public-vm"
  machine_type = "e2-micro"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network = google_compute_network.net.name
    subnetwork = google_compute_subnetwork.public1.name
    access_config {}
  }
}

# PRIVATE INSTANCE
resource "google_compute_instance" "private-vm" {
  name = "private-vm"
  machine_type = "e2-micro"
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network = google_compute_network.net.name
    subnetwork = google_compute_subnetwork.private1.name
  }

  tags = ["iap-tunnel"]
}



