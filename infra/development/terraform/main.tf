provider "google" {
  region = "${var.region}"
  project = "${var.project}"
}

// Network
resource "google_compute_network" "countly-dev-nw" {
  name                    = "countly-dev-nw"
  auto_create_subnetworks = false
}

// Subnetwork
resource "google_compute_subnetwork" "countly-dev-nw-sub-192" {
  name                     = "countly-dev-nw-sub-192"
  ip_cidr_range            = "192.168.100.0/24"
  network                  = google_compute_network.countly-dev-nw.self_link
  region                   = "${var.region}"
  private_ip_google_access = true
}

// Nat-ip
resource "google_compute_address" "countly-dev-nw-ip-nat" {
  name         = "countly-dev-ip-nat"
  address_type = "EXTERNAL"
  network_tier = "PREMIUM"
}

// Nat-ip
resource "google_compute_global_address" "countly-dev-nw-ip-ing" {
  name         = "countly-dev-ip-ing"
}


// Router
resource "google_compute_router" "countly-dev-nw-rt" {
  name     = "countly-dev-nw-rt"
  network  = google_compute_network.countly-dev-nw.self_link
  region   = "${var.region}"
}

// Nat
resource "google_compute_router_nat" "countly-dev-nw-nat" {
  name                               = "countly-dev-nw-nat"
  router                             = "${google_compute_router.countly-dev-nw-rt.name}"
  region                             = "${var.region}"
  nat_ip_allocate_option             = "MANUAL_ONLY"
  nat_ips                            = google_compute_address.countly-dev-nw-ip-nat[*].self_link
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}


// Cluster
resource "google_container_cluster" "countly-dev-cls" {
  name               = "countly-dev-cls"
  location           = "${var.zone}"
  initial_node_count = 1
  min_master_version = "1.12.8-gke.10"
  network            = "${google_compute_network.countly-dev-nw.name}"
  subnetwork         = "${google_compute_subnetwork.countly-dev-nw-sub-192.name}"

  ip_allocation_policy {
    use_ip_aliases           = true
  }

  private_cluster_config {
    enable_private_endpoint = false
    enable_private_nodes    = true
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  node_config {
    oauth_scopes = [
      "https://www.googleapis.com/auth/compute",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
    preemptible  = true
    machine_type = "g1-small"
  }

  master_auth {
    client_certificate_config {
      issue_client_certificate = false
    }
  }

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block = "${var.authorized_networks_cidr}"
      display_name = "${var.authorized_networks_name}"
    }
  }

  addons_config {
    horizontal_pod_autoscaling {
      disabled = false
    }

    http_load_balancing {
      disabled = false
    }

    kubernetes_dashboard {
      disabled = false
    }

    network_policy_config {
      disabled = true
    }
  }
}


// Node-pool
resource "google_container_node_pool" "countly-dev-node" {
  name         = "countly-dev-node"
  location     = "${var.zone}"
  cluster      = "${google_container_cluster.countly-dev-cls.name}"
  node_count   = 1

  node_config {
    oauth_scopes = [
      "https://www.googleapis.com/auth/compute",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
    preemptible  = true
    machine_type = "g1-small"
  }

  autoscaling {
    min_node_count = 1
    max_node_count = 3
  }
}



// Cloud Build
resource "google_cloudbuild_trigger" "countly-dev-build" {
  trigger_template {
    branch_name = "master"
    repo_name   = "${var.cloudbuild_repo_name}"
  }

  filename = "infra/development/deploy/cloudbuild.yml"

  included_files = [
    "api/**",
    "frontend/**"
  ]
}
