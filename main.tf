resource "google_service_account" "nuon_gar_access" {
  project      = var.project_id
  account_id   = var.service_account_id
  display_name = "Nuon GAR access"
  description  = "Service account used by Nuon installs to pull images from Artifact Registry"
}

resource "google_artifact_registry_repository_iam_member" "reader" {
  project    = var.project_id
  location   = var.repository_location
  repository = var.repository_id
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.nuon_gar_access.email}"
}

resource "google_service_account_iam_member" "customer_token_creators" {
  for_each = toset(var.customer_principals)

  service_account_id = google_service_account.nuon_gar_access.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = each.value
}
