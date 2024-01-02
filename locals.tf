resource "random_string" "suffix" {
  length  = 10
  special = false
}

locals {
  postgresql_cluster_name = "vendorcorp-${lower(random_string.suffix.result)}"
}
