terraform {
  required_version = ">= 1.5.0"
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
    kind = {
      source  = "tehcyx/kind"
      version = "~> 0.1"
    }
  }
}

provider "docker" {}

resource "docker_image" "techmart_api" {
  name         = "techmart-api:latest"
  build {
    context    = "${path.module}/../app/backend"
    dockerfile = "Dockerfile"
  }
}

resource "docker_container" "techmart_postgres" {
  image = "postgres:16-alpine"
  name  = "techmart-db"
  env = [
    "POSTGRES_DB=techmart",
    "POSTGRES_USER=postgres",
    "POSTGRES_PASSWORD=postgres"
  ]
  ports {
    internal = 5432
    external = 5432
  }
}

resource "docker_container" "techmart_api" {
  name  = "techmart-api"
  image = docker_image.techmart_api.image_id
  ports {
    internal = 3000
    external = 3000
  }
  env = [
    "PORT=3000",
    "DB_HOST=techmart-db",
    "DB_PORT=5432",
    "DB_NAME=techmart",
    "DB_USER=postgres",
    "DB_PASSWORD=postgres"
  ]
  depends_on = [docker_container.techmart_postgres]
}
