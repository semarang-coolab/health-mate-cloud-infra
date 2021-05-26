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

resource "google_storage_bucket_access_control" "public_rule" {
  bucket = google_storage_bucket.health_mate.name
  role   = "READER"
  entity = "allUsers"
}