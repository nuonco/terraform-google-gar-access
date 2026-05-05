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

### Customers running Nuon-hosted (AWS)

If some of your customers pull from this GAR repo via Nuon-hosted ctl-api running on AWS, pass each customer's AWS account ID via `aws_principals`. The module sets up a Workload Identity Pool + AWS Provider per account and lets the federated principal impersonate the GAR access service account:

```hcl
module "nuon_gar_access" {
  source = "nuonco/gar-access/google"

  project_id          = "<your-gcp-project>"
  repository_location = "us-central1"
  repository_id       = "<repo-name>"

  aws_principals = [
    { aws_account_id = "123456789012" },
  ]
}

output "workload_identity_provider_paths" {
  value = module.nuon_gar_access.workload_identity_provider_paths
}
```

Pass the resulting provider path (keyed by AWS account ID) into the component's `gcp_gar.workload_identity_provider`, alongside the GAR access SA email in `gcp_gar.service_account_email`.

`customer_principals` and `aws_principals` are independent — set whichever apply to your customer mix, both, or neither.
