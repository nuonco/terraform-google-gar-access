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

locals {
  aws_principals_by_account = {
    for p in var.aws_principals : p.aws_account_id => {
      provider_id  = coalesce(p.provider_id, "aws-${substr(p.aws_account_id, length(p.aws_account_id) - 6, 6)}")
      display_name = coalesce(p.display_name, "Nuon-hosted on AWS account ${p.aws_account_id}")
    }
  }
}

resource "google_iam_workload_identity_pool" "nuon_aws" {
  count = length(var.aws_principals) > 0 ? 1 : 0

  project                   = var.project_id
  workload_identity_pool_id = var.workload_identity_pool_id
  display_name              = "Nuon-hosted (AWS)"
  description               = "Federation pool for Nuon-hosted ctl-api running in AWS to access GAR"
}

resource "google_iam_workload_identity_pool_provider" "aws" {
  for_each = local.aws_principals_by_account

  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.nuon_aws[0].workload_identity_pool_id
  workload_identity_pool_provider_id = each.value.provider_id
  display_name                       = each.value.display_name

  aws {
    account_id = each.key
  }

  # Without this, the principalSet binding below silently fails to match.
  attribute_mapping = {
    "google.subject"        = "assertion.arn"
    "attribute.aws_account" = "assertion.account"
    "attribute.aws_role"    = "assertion.arn.contains(\"assumed-role\") ? assertion.arn.extract(\"{account_arn}assumed-role/\") + \"assumed-role/\" + assertion.arn.extract(\"assumed-role/{role_name}/\") : assertion.arn"
  }
}

resource "google_service_account_iam_member" "aws_federated_impersonation" {
  for_each = local.aws_principals_by_account

  service_account_id = google_service_account.nuon_gar_access.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/projects/${data.google_project.this[0].number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.nuon_aws[0].workload_identity_pool_id}/attribute.aws_account/${each.key}"
}

data "google_project" "this" {
  count      = length(var.aws_principals) > 0 ? 1 : 0
  project_id = var.project_id
}
