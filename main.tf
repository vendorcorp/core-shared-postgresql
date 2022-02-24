data "aws_kms_key" "vendorcorp_global_kms_key" {
  key_id = "arn:aws:kms:us-east-2:010904452381:key/mrk-ef697dba5de8478893779bc4b044de8b"
}

module "shared_infrastructure" {
  source      = "git::ssh://git@github.com/sonatype/terraform-shared-infrastructure.git?ref=v0.0.4"
  environment = var.environment
}

resource "aws_db_parameter_group" "dbpg" {
  name        = "${local.postgresql_cluster_name}-parameter-group"
  family      = "aurora-postgresql13"
  description = "${local.postgresql_cluster_name}-parameter-group"
  tags        = var.default_resource_tags
}

resource "aws_rds_cluster_parameter_group" "dbcpg" {
  name        = "${local.postgresql_cluster_name}-cluster-parameter-group"
  family      = "aurora-postgresql13"
  description = "${local.postgresql_cluster_name}-cluster-parameter-group"
  tags        = var.default_resource_tags
}

module "cluster" {
  source = "terraform-aws-modules/rds-aurora/aws"

  name           = local.postgresql_cluster_name
  engine         = "aurora-postgresql"
  engine_version = "13.5"
  instance_class = "db.r5.large"
  instances = {
    one = {}
  }
  deletion_protection = true

  autoscaling_enabled      = true
  autoscaling_min_capacity = 2
  autoscaling_max_capacity = 3

  vpc_id              = module.shared_infrastructure.vpc_id
  subnets             = module.shared_infrastructure.private_subnet_ids
  publicly_accessible = false

  //allowed_security_groups = ["sg-12345678"]
  allowed_cidr_blocks = concat(module.shared_infrastructure.private_subnet_cidrs, ["10.200.0.0/16"])

  kms_key_id          = data.aws_kms_key.vendorcorp_global_kms_key.arn
  storage_encrypted   = true
  apply_immediately   = true
  monitoring_interval = 10

  db_parameter_group_name         = aws_db_parameter_group.dbpg.id
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.dbcpg.id

  enabled_cloudwatch_logs_exports = ["postgresql"]

  tags = var.default_resource_tags
}
