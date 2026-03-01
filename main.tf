terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# --------------------------
# Networking (optional: reuse default network; customize as needed)
# --------------------------
data "google_compute_network" "default" {
  name = var.network_name
}

# --------------------------
# Service Account for VMs
# --------------------------
resource "google_service_account" "vm_sa" {
  account_id   = var.vm_sa_id
  display_name = "VM Instance Group SA"
}

# --------------------------
# Instance Template
# --------------------------
resource "google_compute_instance_template" "tmpl" {
  name_prefix  = "${var.name}-tmpl-"
  machine_type = var.machine_type
  region       = var.region

  disk {
    source_image = var.boot_image
    auto_delete  = true
    boot         = true
    disk_size_gb = var.boot_disk_size_gb
    type         = "pd-balanced"
  }

  network_interface {
    network = data.google_compute_network.default.id
    # To use a specific subnetwork:
    # subnetwork = var.subnetwork_self_link
    access_config {} # Ephemeral public IP; remove if you don't want public IPs
  }

  service_account {
    email  = google_service_account.vm_sa.email
    scopes = var.oauth_scopes
  }

  metadata = {
    enable-oslogin = tostring(var.enable_os_login)
  }

  metadata_startup_script = var.startup_script

  tags = var.instance_tags
}

# --------------------------
# Managed Instance Group (Zonal or Regional)
# --------------------------
# Option A: Zonal MIG
resource "google_compute_instance_group_manager" "mig_zonal" {
  count               = var.mig_scope == "zonal" ? 1 : 0
  name                = "${var.name}-mig"
  base_instance_name  = var.name
  zone                = var.zone
  version {
    instance_template = google_compute_instance_template.tmpl.self_link
    name              = "primary"
  }
  target_size = var.min_replicas
  update_policy {
    type                    = "PROACTIVE"
    minimal_action          = "REPLACE"
    max_surge_fixed         = 1
    max_unavailable_fixed   = 0
    replacement_method      = "RECREATE"
    most_disruptive_allowed_action = "REPLACE"
  }
}

# Option B: Regional MIG
resource "google_compute_region_instance_group_manager" "mig_regional" {
  count              = var.mig_scope == "regional" ? 1 : 0
  name               = "${var.name}-rmig"
  base_instance_name = var.name
  region             = var.region
  distribution_policy_zones = var.regional_zones
  version {
    instance_template = google_compute_instance_template.tmpl.self_link
    name              = "primary"
  }
  target_size = var.min_replicas
  update_policy {
    type                           = "PROACTIVE"
    minimal_action                 = "REPLACE"
    max_surge_fixed                = 1
    max_unavailable_fixed          = 0
    replacement_method             = "RECREATE"
    most_disruptive_allowed_action = "REPLACE"
  }
}

# --------------------------
# Autoscaler (CPU-based)
# --------------------------
resource "google_compute_autoscaler" "autoscaler_zonal" {
  count = var.mig_scope == "zonal" ? 1 : 0
  name  = "${var.name}-autoscaler"
  zone  = var.zone
  target = google_compute_instance_group_manager.mig_zonal[0].self_link

  autoscaling_policy {
    min_replicas    = var.min_replicas
    max_replicas    = var.max_replicas
    cooldown_period = var.cooldown_seconds

    cpu_utilization {
      target = var.cpu_target_utilization
    }
  }
}

resource "google_compute_region_autoscaler" "autoscaler_regional" {
  count  = var.mig_scope == "regional" ? 1 : 0
  name   = "${var.name}-rautoscaler"
  region = var.region
  target = google_compute_region_instance_group_manager.mig_regional[0].self_link

  autoscaling_policy {
    min_replicas    = var.min_replicas
    max_replicas    = var.max_replicas
    cooldown_period = var.cooldown_seconds

    cpu_utilization {
      target = var.cpu_target_utilization
    }
  }
}

# --------------------------
# Firewall Rules
# --------------------------
resource "google_compute_firewall" "allow_ssh" {
  name    = "${var.name}-allow-ssh"
  network = data.google_compute_network.default.name
  allows {
    protocol = "tcp"
    ports    = ["22"]
  }
  direction     = "INGRESS"
  priority      = 1000
  source_ranges = var.ssh_source_ranges
  target_tags   = var.instance_tags
}

resource "google_compute_firewall" "allow_http" {
  name    = "${var.name}-allow-http"
  network = data.google_compute_network.default.name
  allows {
    protocol = "tcp"
    ports    = ["80"]
  }
  direction     = "INGRESS"
  priority      = 1000
  source_ranges = var.web_source_ranges
  target_tags   = var.instance_tags
}

resource "google_compute_firewall" "allow_https" {
  name    = "${var.name}-allow-https"
  network = data.google_compute_network.default.name
  allows {
    protocol = "tcp"
    ports    = ["443"]
  }
  direction     = "INGRESS"
  priority      = 1000
  source_ranges = var.web_source_ranges
  target_tags   = var.instance_tags
}

# --------------------------
# IAM (Least-Privilege Examples)
# --------------------------
# Example: Grant project-level read-only compute to a viewer group
resource "google_project_iam_member" "compute_viewer" {
  count  = length(var.compute_viewer_members)
  project = var.project_id
  role    = "roles/compute.viewer"
  member  = var.compute_viewer_members[count.index]
}

# Example: Limited admin for compute instance admin (v1)
resource "google_project_iam_member" "compute_instance_admin" {
  count  = length(var.compute_instance_admin_members)
  project = var.project_id
  role    = "roles/compute.instanceAdmin.v1"
  member  = var.compute_instance_admin_members[count.index]
}

# Example: Security Admin for firewall manipulations (use sparingly)
resource "google_project_iam_member" "security_admin" {
  count  = length(var.security_admin_members)
  project = var.project_id
  role    = "roles/compute.securityAdmin"
  member  = var.security_admin_members[count.index]
}

# (Optional) Bind roles to the VM service account if needed (e.g., read from GCS)
resource "google_project_iam_member" "vm_sa_storage_object_viewer" {
  count  = var.grant_vm_sa_storage_viewer ? 1 : 0
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.vm_sa.email}"
}
