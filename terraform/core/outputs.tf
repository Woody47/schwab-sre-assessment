output "project_id" { value = var.project_id }
output "clusters" { value = { for k, c in google_container_cluster.gke : k => { name = c.name, zone = c.location, region = local.clusters[k].region } } }
output "image_repository" { value = "us-central1-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.apps.repository_id}/web" }
output "grafana_service_account" { value = google_service_account.grafana.email }
