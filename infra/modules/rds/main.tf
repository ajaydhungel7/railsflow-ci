data "aws_vpc" "this" {
  id = var.vpc_id
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.project}-${var.env}"
  subnet_ids = var.private_subnets
  tags       = { Name = "${var.project}-${var.env}-db-subnet-group" }
}

resource "aws_security_group" "rds" {
  name   = "${var.project}-${var.env}-rds"
  vpc_id = var.vpc_id
  tags   = { Name = "${var.project}-${var.env}-rds" }

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.this.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "this" {
  identifier        = "${var.project}-${var.env}"
  engine            = "postgres"
  engine_version    = var.engine_version
  instance_class    = var.instance_class
  allocated_storage = var.allocated_storage

  db_name  = var.db_name
  username = var.db_username
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  storage_encrypted   = true
  multi_az            = var.multi_az
  skip_final_snapshot = true

  tags = { Name = "${var.project}-${var.env}-db" }
}
