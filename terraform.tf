project_id  = "cloud comupting"
region      = "asia-south1"
zone        = "asia-south1-a"
name        = "prod-web"
mig_scope   = "zonal" # or "regional"

min_replicas           = 1
max_replicas           = 5
cpu_target_utilization = 0.6
cooldown_seconds       = 40

machine_type  = "e2-medium"
instance_tags = ["mig-web"]

ssh_source_ranges = ["203.0.113.10/32"]  # replace with your corporate IPs
web_source_ranges = ["0.0.0.0/0"]

compute_viewer_members         = ["group:readers@example.com"]
compute_instance_admin_members = ["group:ops@example.com"]
security_admin_members         = []        # keep empty unless really needed

grant_vm_sa_storage_viewer = false
