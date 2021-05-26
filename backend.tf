terraform {
  backend "remote" {
    organization = "semarang-coolab"

    workspaces {
      name = "health-mate"
    }
  }
}