resource "google_secret_manager_secret" "id" {
  secret_id = var.secret_id
  replication {
    automatic = true
  }
}

resource "google_secret_manager_secret_version" "data" {
  secret      = google_secret_manager_secret.id.name
  secret_data = var.secret_data
}

resource "google_secret_manager_secret_iam_member" "secret-access" {
  secret_id  = google_secret_manager_secret.id.id
  role       = "roles/secretmanager.secretAccessor"
  member     = "serviceAccount:${var.project}-compute@developer.gserviceaccount.com"
  depends_on = [google_secret_manager_secret.id]
}
