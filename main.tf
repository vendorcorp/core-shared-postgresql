data "aws_kms_key" "vendorcorp_global_kms_key" {
  key_id = "arn:aws:kms:us-east-2:010904452381:key/mrk-ef697dba5de8478893779bc4b044de8b"
}

module "shared_infrastructure" {
  source      = "git::ssh://git@github.com/sonatype/terraform-shared-infrastructure.git?ref=v0.0.4"
  environment = var.environment
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

  autoscaling_enabled      = true
  autoscaling_min_capacity = 1
  autoscaling_max_capacity = 2

  vpc_id              = module.shared_infrastructure.vpc_id
  subnets             = module.shared_infrastructure.private_subnet_ids
  publicly_accessible = false

  allowed_security_groups = ["sg-12345678"]
  allowed_cidr_blocks     = concat(module.shared_infrastructure.private_subnet_cidrs, ["10.200.0.0/16"])

  kms_key_id          = aws_kms_key.vendorcorp_global_kms_key.id
  storage_encrypted   = true
  apply_immediately   = true
  monitoring_interval = 10

  db_parameter_group_name         = "default"
  db_cluster_parameter_group_name = "default"

  enabled_cloudwatch_logs_exports = ["postgresql"]

  tags = var.default_resource_tags
}
