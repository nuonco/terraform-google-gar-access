locals {
  all_repositories    = distinct(compact(concat(var.repository_id != null ? [var.repository_id] : [], var.repositories)))
  exact_repositories  = [for r in local.all_repositories : r if !endswith(r, "*")]
  repository_prefixes = [for r in local.all_repositories : trimsuffix(r, "*") if endswith(r, "*")]
}

resource "google_service_account" "nuon_gar_access" {
  project      = var.project_id
  account_id   = var.service_account_id
  display_name = "Nuon GAR access"
  description  = "Service account used by Nuon installs to pull images from Artifact Registry"

  lifecycle {
    precondition {
      condition     = length(local.all_repositories) > 0
      error_message = "Set `repositories` (or the deprecated `repository_id`) to at least one repository ID or prefix pattern."
    }
  }
}

resource "google_artifact_registry_repository_iam_member" "reader" {
  for_each = toset(local.exact_repositories)

  project    = var.project_id
  location   = var.repository_location
  repository = each.value
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.nuon_gar_access.email}"
}

resource "google_project_iam_member" "prefix_reader" {
  for_each = toset(local.repository_prefixes)

  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.nuon_gar_access.email}"

  condition {
    title       = "nuon-gar-access-${each.value == "" ? "all" : replace(each.value, "/[^a-zA-Z0-9-]/", "-")}"
    description = "Artifact Registry repositories matching ${each.value}* in ${var.repository_location}"
    expression  = "resource.name.startsWith(\"projects/${var.project_id}/locations/${var.repository_location}/repositories/${each.value}\")"
  }
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

locals {
  azure_principals_by_id = {
    for p in var.azure_principals : p.principal_id => {
      tenant_id    = p.tenant_id
      audience     = coalesce(p.audience, "api://AzureADTokenExchange")
      provider_id  = coalesce(p.provider_id, "azure-${substr(replace(p.principal_id, "-", ""), 0, 12)}")
      display_name = coalesce(p.display_name, "Nuon self-hosted on Azure identity ${p.principal_id}")
    }
  }
}

resource "google_iam_workload_identity_pool" "nuon_azure" {
  count = length(var.azure_principals) > 0 ? 1 : 0

  project                   = var.project_id
  workload_identity_pool_id = var.azure_workload_identity_pool_id
  display_name              = "Nuon self-hosted (Azure)"
  description               = "Federation pool for Nuon ctl-api running in Azure to access GAR"
}

resource "google_iam_workload_identity_pool_provider" "azure" {
  for_each = local.azure_principals_by_id

  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.nuon_azure[0].workload_identity_pool_id
  workload_identity_pool_provider_id = each.value.provider_id
  display_name                       = each.value.display_name

  oidc {
    issuer_uri        = "https://sts.windows.net/${each.value.tenant_id}/"
    allowed_audiences = [each.value.audience]
  }

  attribute_mapping = {
    "google.subject" = "assertion.sub"
  }
}

resource "google_service_account_iam_member" "azure_federated_impersonation" {
  for_each = local.azure_principals_by_id

  service_account_id = google_service_account.nuon_gar_access.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principal://iam.googleapis.com/projects/${data.google_project.this[0].number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.nuon_azure[0].workload_identity_pool_id}/subject/${each.key}"
}

data "google_project" "this" {
  count      = length(var.aws_principals) > 0 || length(var.azure_principals) > 0 ? 1 : 0
  project_id = var.project_id
}
