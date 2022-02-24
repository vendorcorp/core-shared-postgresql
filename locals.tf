resource "random_string" "suffix" {
  length  = 8
  special = false
}

locals {
  postgresql_cluster_name = "vendorcorp-${var.aws_region}-${lower(random_string.suffix.result)}"
}
