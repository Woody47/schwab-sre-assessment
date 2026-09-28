locals {
  clusters = {
    primary   = { zone = "us-central1-a", region = "us-central1", subnet = "10.10.0.0/20", pods = "10.20.0.0/16", services = "10.30.0.0/20", master = "172.16.0.0/28" }
    secondary = { zone = "us-east1-b", region = "us-east1", subnet = "10.40.0.0/20", pods = "10.50.0.0/16", services = "10.60.0.0/20", master = "172.16.0.16/28" }
  }
  apis   = toset(["compute.googleapis.com", "container.googleapis.com", "artifactregistry.googleapis.com", "logging.googleapis.com", "monitoring.googleapis.com", "bigquery.googleapis.com", "iam.googleapis.com", "iamcredentials.googleapis.com", "cloudresourcemanager.googleapis.com"])
  grants = merge({}, [for role, members in var.iam_bindings : { for member in members : "${role}/${member}" => { role = role, member = member } }]...)
}
resource "google_project" "assessment" {
  count           = var.create_project ? 1 : 0
  project_id      = var.project_id
  name            = "Woody SRE Assessment"
  billing_account = var.billing_account
  folder_id       = var.folder_id
  deletion_policy = "PREVENT"
}
resource "google_project_service" "api" {
  for_each           = local.apis
  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
  depends_on         = [google_project.assessment]
}
resource "google_project_iam_member" "team" {
  for_each   = local.grants
  project    = var.project_id
  role       = each.value.role
  member     = each.value.member
  depends_on = [google_project_service.api]
}
resource "google_compute_network" "main" {
  name                    = "sre-assessment"
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
  depends_on              = [google_project_service.api]
}
resource "google_compute_subnetwork" "gke" {
  for_each                 = local.clusters
  name                     = "gke-${each.key}"
  region                   = each.value.region
  network                  = google_compute_network.main.id
  ip_cidr_range            = each.value.subnet
  private_ip_google_access = true
  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = each.value.pods
  }
  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = each.value.services
  }
}
resource "google_compute_router" "main" {
  for_each = local.clusters
  name     = "nat-${each.key}"
  region   = each.value.region
  network  = google_compute_network.main.id
}
resource "google_compute_router_nat" "main" {
  for_each                           = local.clusters
  name                               = "nat-${each.key}"
  router                             = google_compute_router.main[each.key].name
  region                             = each.value.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  subnetwork {
    name                    = google_compute_subnetwork.gke[each.key].id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}
resource "google_service_account" "nodes" {
  account_id = "sre-gke-nodes"
  depends_on = [google_project_service.api]
}
resource "google_project_iam_member" "nodes" {
  for_each = toset(["roles/container.defaultNodeServiceAccount", "roles/artifactregistry.reader"])
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.nodes.email}"
}
resource "google_container_cluster" "gke" {
  for_each                 = local.clusters
  name                     = "sre-${each.key}"
  location                 = each.value.zone
  network                  = google_compute_network.main.id
  subnetwork               = google_compute_subnetwork.gke[each.key].id
  remove_default_node_pool = true
  initial_node_count       = 1
  deletion_protection      = var.deletion_protection
  networking_mode          = "VPC_NATIVE"
  release_channel { channel = "REGULAR" }
  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = each.value.master
  }
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = var.admin_cidr
      display_name = "operator"
    }
  }
  workload_identity_config { workload_pool = "${var.project_id}.svc.id.goog" }
  logging_config { enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS", "API_SERVER", "SCHEDULER", "CONTROLLER_MANAGER"] }
  monitoring_config { enable_components = ["SYSTEM_COMPONENTS"] }
  network_policy { enabled = true }
  addons_config {
    network_policy_config { disabled = false }
  }
  depends_on = [google_project_service.api, google_compute_router_nat.main, google_project_iam_member.nodes]
}
resource "google_container_node_pool" "general" {
  for_each           = local.clusters
  name               = "general"
  cluster            = google_container_cluster.gke[each.key].id
  location           = each.value.zone
  initial_node_count = 1
  autoscaling {
    min_node_count = 1
    max_node_count = 3
  }
  management {
    auto_repair  = true
    auto_upgrade = true
  }
  node_config {
    machine_type    = var.machine_type
    disk_size_gb    = 30
    disk_type       = "pd-standard"
    service_account = google_service_account.nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
    tags            = ["sre-gke"]
    workload_metadata_config { mode = "GKE_METADATA" }
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }
}
resource "google_compute_firewall" "edge" {
  name          = "sre-allow-google-proxies"
  network       = google_compute_network.main.name
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = ["sre-gke"]
  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }
}
resource "google_compute_firewall" "monitoring_webhook" {
  name          = "sre-monitoring-webhook"
  network       = google_compute_network.main.name
  source_ranges = [for c in local.clusters : c.master]
  target_tags   = ["sre-gke"]
  allow {
    protocol = "tcp"
    ports    = ["10250"]
  }
}
resource "google_artifact_registry_repository" "apps" {
  location      = "us-central1"
  repository_id = "sre-apps"
  format        = "DOCKER"
  depends_on    = [google_project_service.api]
}
resource "google_bigquery_dataset" "logs" {
  dataset_id                  = "sre_logs"
  location                    = "US"
  default_table_expiration_ms = 604800000
  delete_contents_on_destroy  = false
  depends_on                  = [google_project_service.api]
}
resource "google_logging_project_sink" "bigquery" {
  name                   = "sre-logs-bigquery"
  destination            = "bigquery.googleapis.com/${google_bigquery_dataset.logs.id}"
  unique_writer_identity = true
  filter                 = "(resource.type=\"k8s_container\" AND resource.labels.namespace_name=\"apps\") OR resource.type=(\"k8s_node\" OR \"k8s_cluster\")"
  bigquery_options { use_partitioned_tables = true }
}
resource "google_bigquery_dataset_iam_member" "sink" {
  dataset_id = google_bigquery_dataset.logs.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = google_logging_project_sink.bigquery.writer_identity
}
resource "google_service_account" "grafana" {
  account_id = "sre-grafana"
  depends_on = [google_project_service.api]
}
resource "google_project_iam_member" "grafana" {
  for_each = toset(["roles/bigquery.jobUser", "roles/browser"])
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.grafana.email}"
}
resource "google_bigquery_dataset_iam_member" "grafana" {
  dataset_id = google_bigquery_dataset.logs.dataset_id
  role       = "roles/bigquery.dataViewer"
  member     = "serviceAccount:${google_service_account.grafana.email}"
}
resource "google_service_account_iam_member" "grafana_workload" {
  service_account_id = google_service_account.grafana.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[monitoring/grafana]"
}
