variable "gcp_service_account" {}
variable "gcp_project_id" {}
variable "gcp_project_region" {
  default = "asia-southeast2"
}
variable "gcp_project_zone" {
  default = "asia-southeast2-a"
}

variable "sql_instance_authorized_network" {}
variable "sql_instance_user" {}
variable "sql_instance_password" {}

variable "db_name" {}
variable "jwt_key" {}
