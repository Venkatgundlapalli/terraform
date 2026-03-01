variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "asia-south1"
}

variable "zone" {
  description = "GCP zone (for zonal MIG)"
  type        = string
  default     = "asia-south1-a"
}

variable "name" {
  description = "Base name for resources"
  type        = string
  default     = "autoscaling-demo"
}

variable "network_name" {
  description = "Network to use (default means the default VPC)"
  type        = string
  default     = "default"
}

variable "subnetwork_self_link" {
  description = "Optional subnetwork self_link (leave empty to use default network without specifying subnet)"
  type        = string
  default     = ""
}

variable "machine_type" {
  description = "Machine type for instances"
  type        = string
  default     = "e2-medium"
}

variable "boot_image" {
  description = "Source image for boot disk"
  type        = string
  # Example: Ubuntu 22.04 LTS family
  default     = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2204-lts"
}

variable "boot_disk_size_gb" {
  description = "Boot disk size in GB"
  type        = number
  default     = 20
}

variable "oauth_scopes" {
  description = "OAuth scopes for the instance service account"
  type        = list(string)
  default     = ["https://www.googleapis.com/auth/cloud-platform"]
}

variable "enable_os_login" {
  description = "Enable OS Login for SSH (recommended)"
  type        = bool
  default     = true
}

variable "startup_script" {
  description = "Startup script for the instance template"
  type        = string
  default     = <<-EOT
    #!/usr/bin/env bash
    set -euo pipefail
    apt-get update -y
    apt-get install -y nginx
    systemctl enable nginx
    systemctl start nginx
    echo "<h1>MIG instance $(hostname)</h1>" > /var/www/html/index.nginx-debian.html
  EOT
}

variable "instance_tags" {
  description = "Network tags applied to instances (used by firewall rules)"
  type        = list(string)
  default     = ["mig-web"]
}

variable "mig_scope" {
  description = "Scope of MIG: 'zonal' or 'regional'"
  type        = string
  default     = "zonal"
  validation {
    condition     = contains(["zonal", "regional"], var.mig_scope)
    error_message = "mig_scope must be 'zonal' or 'regional'."
  }
}

variable "regional_zones" {
  description = "Zones for regional MIG distribution policy"
  type        = list(string)
  default     = ["asia-south1-a", "asia-south1-b", "asia-south1-c"]
}

variable "min_replicas" {
  description = "Minimum instances in the MIG"
  type        = number
  default     = 1
}

variable "max_replicas" {
  description = "Maximum instances in the MIG"
  type        = number
  default     = 5
}

variable "cpu_target_utilization" {
  description = "CPU target utilization (0-1)"
  type        = number
  default     = 0.6
}

variable "cooldown_seconds" {
  description = "Cooldown period for autoscaler"
  type        = number
  default     = 60
}

variable "ssh_source_ranges" {
  description = "Allowed CIDRs for SSH"
  type        = list(string)
  default     = ["YOUR_OFFICE_IP/32"] # Replace with corporate IP(s)
}

variable "web_source_ranges" {
  description = "Allowed CIDRs for HTTP/HTTPS"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "vm_sa_id" {
  description = "ID (short name) for the VM service account"
  type        = string
  default     = "mig-vm-sa"
}

variable "compute_viewer_members" {
  description = "Members (e.g., 'group:ops@example.com') to grant compute.viewer"
  type        = list(string)
  default     = []
}

variable "compute_instance_admin_members" {
  description = "Members to grant compute.instanceAdmin.v1"
  type        = list(string)
  default     = []
}

variable "security_admin_members" {
  description = "Members to grant compute.securityAdmin (for firewall ops)"
  type        = list(string)
  default     = []
}

variable "grant_vm_sa_storage_viewer" {
  description = "Grant storage.objectViewer to the VM service account"
  type        = bool
  default     = false
}
