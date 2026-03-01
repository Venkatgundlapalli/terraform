output "instance_template" {
  value = google_compute_instance_template.tmpl.self_link
}

output "mig_self_link" {
  value = var.mig_scope == "zonal"
    ? google_compute_instance_group_manager.mig_zonal[0].self_link
    : google_compute_region_instance_group_manager.mig_regional[0].self_link
}

output "autoscaler_name" {
  value = var.mig_scope == "zonal"
    ? google_compute_autoscaler.autoscaler_zonal[0].name
    : google_compute_region_autoscaler.autoscaler_regional[0].name
}

output "vm_service_account_email" {
  value = google_service_account.vm_sa.email
}
