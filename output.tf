output "service_account_email" {
  value       = google_service_account.nuon_gar_access.email
  description = "Email of the GAR access service account. Use this in the `gcp_gar.service_account_email` field of your Nuon container_image component."
}

output "service_account_unique_id" {
  value       = google_service_account.nuon_gar_access.unique_id
  description = "Numeric uniqueId of the GAR access service account."
}

output "workload_identity_provider_paths" {
  value = {
    for account_id, _ in local.aws_principals_by_account :
    account_id => "${google_iam_workload_identity_pool.nuon_aws[0].name}/providers/${google_iam_workload_identity_pool_provider.aws[account_id].workload_identity_pool_provider_id}"
  }
  description = "Map of AWS account ID to provider path. Use as `gcp_gar.workload_identity_provider`."
}
