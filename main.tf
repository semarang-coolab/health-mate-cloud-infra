resource "google_storage_bucket" "health_mate" {
  name          = "semarang-coolab-health-mate-dev-storage"
  location      = "ASIA-SOUTHEAST2"
  force_destroy = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      num_newer_versions = 3
    }
    action {
      type = "Delete"
    }
  }
}

resource "google_storage_default_object_access_control" "public_rule" {
  bucket = google_storage_bucket.health_mate.name
  role   = "READER"
  entity = "allUsers"
}

resource "google_compute_network" "net_one" {
  name                    = "semarang-coolab-healthmate-dev-vpc-1"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "southeast2_subnetwork" {
  name          = "semarang-coolab-healthmate-se-2-dev-subnet"
  ip_cidr_range = "10.1.0.0/24"
  network       = google_compute_network.net_one.id
}

resource "google_compute_global_address" "private_ip_address" {
  name          = "semarang-coolab-healthmate-dev-private-ip"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 24
  network       = google_compute_network.net_one.id
}

resource "google_service_networking_connection" "private" {
  network                 = google_compute_network.net_one.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}

resource "google_sql_database_instance" "healthmate_db" {
  name                = "semarang-coolab-healthmate-dev-db"
  database_version    = "POSTGRES_13"
  deletion_protection = false

  depends_on = [
    google_service_networking_connection.private
  ]

  settings {
    tier              = "db-f1-micro"
    availability_type = "ZONAL"
    disk_autoresize   = false
    ip_configuration {
      ipv4_enabled = true
      authorized_networks {
        value = var.sql_instance_authorized_network
      }
      private_network = google_compute_network.net_one.id
    }
  }
}

resource "google_sql_user" "name" {
  name            = var.sql_instance_user
  password        = var.sql_instance_password
  instance        = google_sql_database_instance.healthmate_db.name
  deletion_policy = "ABANDON"
}
