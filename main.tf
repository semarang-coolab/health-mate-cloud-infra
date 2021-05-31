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

data "google_project" "project" {}

module "db_user" {
  source      = "./secrets"
  secret_id   = "dbuser"
  secret_data = var.sql_instance_user
  project     = data.google_project.project.number
}

module "db_password" {
  source      = "./secrets"
  secret_id   = "dbpassword"
  secret_data = var.sql_instance_password
  project     = data.google_project.project.number
}

module "db_name" {
  source      = "./secrets"
  secret_id   = "dbname"
  secret_data = var.db_name
  project     = data.google_project.project.number
}

module "jwt_key" {
  source      = "./secrets"
  secret_id   = "jwtkey"
  secret_data = var.jwt_key
  project     = data.google_project.project.number
}

resource "google_vpc_access_connector" "private" {
  provider      = google-beta
  name          = "mukti-test-dev-conn"
  ip_cidr_range = "10.123.0.0/28"
  network       = google_compute_network.net_one.name
  machine_type  = "f1-micro"
}

resource "google_cloud_run_service" "healthmate-api" {
  provider = google-beta
  name     = "cloudrun-srv"
  location = var.gcp_project_region

  metadata {
    annotations = {
      "run.googleapis.com/launch-stage" = "BETA"
    }
  }

  template {
    metadata {
      annotations = {
        "run.googleapis.com/vpc-access-connector" = google_vpc_access_connector.private.name
      }
    }
    spec {
      containers {
        image = "asia.gcr.io/${var.gcp_project_id}/health-mate-api"
        ports {
          container_port = 8080
        }
        env {
          name  = "DB_HOST"
          value = google_sql_database_instance.healthmate_db.private_ip_address
        }
        env {
          name  = "DB_PORT"
          value = "5432"
        }
        env {
          name = "DB_USER"
          value_from {
            secret_key_ref {
              name = module.db_user.secret_id
              key  = "latest"
            }
          }
        }
        env {
          name = "DB_PASSWORD"
          value_from {
            secret_key_ref {
              name = module.db_password.secret_id
              key  = "latest"
            }
          }
        }
        env {
          name = "DB_NAME"
          value_from {
            secret_key_ref {
              name = module.db_name.secret_id
              key  = "latest"
            }
          }
        }
        env {
          name  = "BUCKET_NAME"
          value = google_storage_bucket.health_mate.name
        }
        env {
          name = "JWT_KEY"
          value_from {
            secret_key_ref {
              name = module.jwt_key.secret_id
              key  = "latest"
            }
          }
        }
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
}

data "google_iam_policy" "noauth" {
  binding {
    role = "roles/run.invoker"
    members = [
      "allUsers",
    ]
  }
}

resource "google_cloud_run_service_iam_policy" "noauth" {
  location = google_cloud_run_service.healthmate-api.location
  project  = google_cloud_run_service.healthmate-api.project
  service  = google_cloud_run_service.healthmate-api.name

  policy_data = data.google_iam_policy.noauth.policy_data
}
