variable "service_account_id" {
  type        = string
  default     = "nuon-gar-access"
  description = "Service account ID to create. Must be unique within the GCP project."
}

variable "project_id" {
  type        = string
  description = "GCP project ID that owns the Artifact Registry repository."
}

variable "repository_location" {
  type        = string
  description = "Location of the Artifact Registry repository (e.g. \"us-central1\")."
}

variable "repository_id" {
  type        = string
  description = "Artifact Registry repository ID (the repository name)."
}

variable "customer_principals" {
  type        = list(string)
  default     = []
  description = <<-EOT
    Principals allowed to impersonate the access service account. For customers
    running self-hosted Nuon on GCP, this is their ctl-api service account in
    `serviceAccount:<email>` form. You can also pass a `principalSet:` for a
    Workload Identity Pool.
  EOT
}

variable "workload_identity_pool_id" {
  type        = string
  default     = "nuon-aws"
  description = "ID of the Workload Identity Pool created when `aws_principals` is set. One pool is shared across all AWS accounts."
}

variable "aws_principals" {
  type = list(object({
    aws_account_id = string
    provider_id    = optional(string)
    display_name   = optional(string)
  }))
  default     = []
  description = "AWS accounts allowed to federate via Workload Identity Federation. One provider is created per entry. `provider_id` defaults to `aws-<last 6 chars of account_id>`."
}
