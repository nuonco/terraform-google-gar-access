# Terraform Google GAR Access

A module for setting up Google Artifact Registry access for [container image](https://docs.nuon.co/guides/container-image-components#gcp-gar-access) components on Nuon. This module is intended to be published to the Terraform Registry as `nuonco/gar-access/google`.

## Usage

To set up a service account that lets [self-hosted Nuon on GCP](https://docs.nuon.co/guides/self-hosted/gcp) customers pull images from your Artifact Registry repository:

```hcl
module "nuon_gar_access" {
  source = "nuonco/gar-access/google"

  project_id          = "<your-gcp-project>"
  repository_location = "us-central1"
  repository_id       = "<repo-name>"

  customer_principals = [
    "serviceAccount:ctl-api-<install>@<customer-project>.iam.gserviceaccount.com",
  ]
}

output "gar_access_sa_email" {
  value = module.nuon_gar_access.service_account_email
}
```

Pass the resulting service account email into your component's `gcp_gar.service_account_email` field.

Each entry in `customer_principals` is the IAM member string for a customer's ctl-api service account. The module grants those principals `roles/iam.serviceAccountTokenCreator` so they can impersonate the GAR access service account when pulling images.
