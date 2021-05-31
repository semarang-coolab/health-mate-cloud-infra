provider "google" {
  credentials = file(var.gcp_service_account)

  project = var.gcp_project_id
  region  = "asia-southeast2"
  zone    = "asia-southeast2-a"
}

provider "google-beta" {
  credentials = file(var.gcp_service_account)

  project = var.gcp_project_id
  region  = "asia-southeast2"
  zone    = "asia-southeast2-a"
}
