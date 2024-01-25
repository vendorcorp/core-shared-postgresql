################################################################################
# KMS Key for RDS encryption
################################################################################
resource "aws_kms_key" "rds_kms_key" {
  description             = "RDS Secret Encryption Key"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = var.default_resource_tags
}

################################################################################
# Load VendorCorp Shared Infra
################################################################################
module "shared" {
  source      = "git::ssh://git@github.com/vendorcorp/terraform-shared-private-infrastructure.git?ref=v1.4.4"
  environment = var.environment
}

module "shared_public" {
  source      = "git::ssh://git@github.com/vendorcorp/terraform-shared-infrastructure.git?ref=v1.0.1"
}

################################################################################
# Connect to our k8s Cluster
################################################################################
provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = module.shared_public.eks_cluster_arn
}


# resource "aws_db_parameter_group" "dbpg" {
#   name        = "${local.postgresql_cluster_name}-parameter-group"
#   family      = "aurora-postgresql15"
#   description = "${local.postgresql_cluster_name}-parameter-group"
#   tags        = var.default_resource_tags
# }

# resource "aws_rds_cluster_parameter_group" "dbcpg" {
#   name        = "${local.postgresql_cluster_name}-cluster-parameter-group"
#   family      = "aurora-postgresql15"
#   description = "${local.postgresql_cluster_name}-cluster-parameter-group"
#   tags        = var.default_resource_tags

#   parameter {
#     name = ""
#     value = ""
#   }
# }

module "cluster" {
  source = "terraform-aws-modules/rds-aurora/aws"

  name            = local.postgresql_cluster_name
  engine          = "aurora-postgresql"
  engine_version  = "15.3"
  master_username = "root"
  storage_type    = "aurora-iopt1"
  instance_class  = "db.r6g.large"
  instances = {
    one = {}
  }
  deletion_protection = true

  autoscaling_enabled      = true
  autoscaling_min_capacity = 1
  autoscaling_max_capacity = 2

  ca_cert_identifier      = "rds-ca-rsa2048-g1"

  vpc_id                  = module.shared.vpc_id
  subnets                 = module.shared.private_subnet_ids
  create_db_subnet_group  = true
  publicly_accessible     = false

  security_group_rules = module.shared.gin_enabled ? { 
    ingress = {
      cidr_blocks = concat(module.shared.private_subnet_cidrs, ["10.200.0.0/16"])
    } 
  } : {
    ingress = {
      # VPN users NAT in from public subnet, EKS connects from private subnets
      cidr_blocks = concat(module.shared.private_subnet_cidrs, module.shared.public_subnet_cidrs)
    }
  }

  kms_key_id          = aws_kms_key.rds_kms_key.arn
  storage_encrypted   = true
  monitoring_interval = 10
  apply_immediately   = true
  skip_final_snapshot = true

  // DB Parameter Group
  # db_parameter_group_name         = aws_db_parameter_group.dbpg.id
  # db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.dbcpg.id

  # enabled_cloudwatch_logs_exports = ["postgresql"]

  tags = var.default_resource_tags
}

################################################################################
# Create ConfigMap for gatus monitoring
################################################################################
resource "kubernetes_config_map" "gatus" {
  metadata {
    name = "gatus-config-core-shared-postgresql"
    labels = {
      "gatus.io/enabled": "true"
    }
  }

  data = {
    "core-shared-postgresql.yaml": "${file("gatus.yaml")}"
  }
}