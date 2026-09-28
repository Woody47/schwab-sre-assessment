terraform {
  required_version = ">= 1.6, < 2.0"
  required_providers {
    google = { source = "hashicorp/google", version = "7.46.1" }
  }
}
variable "project_id" { type = string }
variable "backends" {
  type = map(list(object({ name = string, zone = string })))
  validation {
    condition     = contains(keys(var.backends), "app-a") && contains(keys(var.backends), "app-b") && alltrue([for v in values(var.backends) : length(v) >= 2])
    error_message = "Both applications require NEGs from both clusters."
  }
}
variable "domain" {
  type        = string
  default     = ""
  description = "Optional owned DNS hostname; enables managed TLS."
}
provider "google" { project = var.project_id }
locals {
  negs = merge([for app, backends in var.backends : { for b in backends : "${app}/${b.zone}/${b.name}" => b }]...)
}
data "google_compute_network_endpoint_group" "pods" {
  for_each = local.negs
  name     = each.value.name
  zone     = each.value.zone
}
resource "google_compute_global_address" "web" { name = "sre-global-web" }
resource "google_compute_health_check" "web" {
  name               = "sre-web"
  check_interval_sec = 10
  timeout_sec        = 5
  http_health_check {
    port         = 8080
    request_path = "/readyz"
  }
}
resource "google_compute_backend_service" "web" {
  for_each                        = var.backends
  name                            = "sre-${each.key}"
  protocol                        = "HTTP"
  port_name                       = "http"
  load_balancing_scheme           = "EXTERNAL_MANAGED"
  health_checks                   = [google_compute_health_check.web.id]
  connection_draining_timeout_sec = 30
  log_config {
    enable      = true
    sample_rate = 1.0
  }
  dynamic "backend" {
    for_each = each.value
    content {
      group                 = data.google_compute_network_endpoint_group.pods["${each.key}/${backend.value.zone}/${backend.value.name}"].self_link
      balancing_mode        = "RATE"
      max_rate_per_endpoint = 50
    }
  }
}
resource "google_compute_url_map" "web" {
  name            = "sre-web"
  default_service = google_compute_backend_service.web["app-a"].id
  host_rule {
    hosts        = ["*"]
    path_matcher = "apps"
  }
  path_matcher {
    name            = "apps"
    default_service = google_compute_backend_service.web["app-a"].id
    path_rule {
      paths   = ["/app-b", "/app-b/*"]
      service = google_compute_backend_service.web["app-b"].id
    }
  }
}
resource "google_compute_target_http_proxy" "web" {
  name    = "sre-web-http"
  url_map = var.domain == "" ? google_compute_url_map.web.id : google_compute_url_map.redirect[0].id
}
resource "google_compute_global_forwarding_rule" "http" {
  name                  = "sre-web-http"
  target                = google_compute_target_http_proxy.web.id
  ip_address            = google_compute_global_address.web.address
  port_range            = "80"
  load_balancing_scheme = "EXTERNAL_MANAGED"
}
resource "google_compute_managed_ssl_certificate" "web" {
  count = var.domain == "" ? 0 : 1
  name  = "sre-web-cert"
  managed { domains = [var.domain] }
}
resource "google_compute_target_https_proxy" "web" {
  count            = var.domain == "" ? 0 : 1
  name             = "sre-web-https"
  url_map          = google_compute_url_map.web.id
  ssl_certificates = [google_compute_managed_ssl_certificate.web[0].id]
}
resource "google_compute_global_forwarding_rule" "https" {
  count                 = var.domain == "" ? 0 : 1
  name                  = "sre-web-https"
  target                = google_compute_target_https_proxy.web[0].id
  ip_address            = google_compute_global_address.web.address
  port_range            = "443"
  load_balancing_scheme = "EXTERNAL_MANAGED"
}
resource "google_compute_url_map" "redirect" {
  count = var.domain == "" ? 0 : 1
  name  = "sre-https-redirect"
  default_url_redirect {
    https_redirect         = true
    strip_query            = false
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
  }
}
output "ip" { value = google_compute_global_address.web.address }
output "url" { value = var.domain == "" ? "http://${google_compute_global_address.web.address}" : "https://${var.domain}" }
