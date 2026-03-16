# A subnet group tells RDS which subnets it's allowed to use
resource "aws_db_subnet_group" "this" {
  name       = "supportdesk-db-subnet-group"
  subnet_ids = var.subnet_ids
}

# Security group: controls who can talk to the DB on port 5432
resource "aws_security_group" "db" {
  name   = "supportdesk-db-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    # Only allow traffic FROM the app's security group
    security_groups = [var.app_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "postgres" {
  identifier        = "supportdesk-db"
  engine            = "postgres"
  engine_version    = "15"
  instance_class    = "db.t3.micro"   # free tier eligible
  allocated_storage = 20

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.db.id]

  multi_az            = false
  skip_final_snapshot = true

  # Don't expose this to the internet
  publicly_accessible = false
}