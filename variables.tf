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
  default     = null
  description = "Artifact Registry repository ID (the repository name). Deprecated: use `repositories`."
}

variable "repositories" {
  type        = list(string)
  default     = []
  description = <<-EOT
    Repository IDs and/or prefix patterns to grant read access to. Plain entries
    (e.g. "my-repo") get a repository-level reader grant. Entries ending in `*`
    (e.g. "team-*") get a project-level reader grant scoped with an IAM condition
    to repositories matching that prefix in `repository_location`. GCP IAM does
    not support full regex; a trailing `*` prefix match is the only pattern form.
  EOT

  validation {
    condition     = alltrue([for r in var.repositories : !can(regex("\\*", trimsuffix(r, "*")))])
    error_message = "`*` is only supported as a trailing wildcard for prefix matching, e.g. \"team-*\"."
  }
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
  description = "AWS accounts allowed to federate via Workload Identity Federation. One provider is created per entry. `provider_id` defaults to `aws-<last 6 chars of account_id>`, and `display_name` to `Nuon AWS <account_id>`."

  # Caught at plan time rather than part-way through an apply, which otherwise
  # leaves the service account and repository binding created but no provider.
  validation {
    condition = alltrue([
      for p in var.aws_principals :
      p.display_name == null || length(coalesce(p.display_name, "")) <= 32
    ])
    error_message = "display_name must be 32 characters or fewer; Google rejects longer workload identity provider display names."
  }
}
