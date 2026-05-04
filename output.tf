output "service_account_email" {
  value       = google_service_account.nuon_gar_access.email
  description = "Email of the GAR access service account. Use this in the `gcp_gar.service_account_email` field of your Nuon container_image component."
}

output "service_account_unique_id" {
  value       = google_service_account.nuon_gar_access.unique_id
  description = "Numeric uniqueId of the GAR access service account."
}
