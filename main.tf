# Providers for both regions
provider "aws" {
  alias  = "us_east_2"
  region = "us-east-2"
}

provider "aws" {
  alias  = "us_west_2"
  region = "us-west-2"
}

# Primary VPC in us-east-2
resource "aws_vpc" "primary_vpc" {
  provider = aws.us_east_2
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = "primary-vpc"
  }
}

# Subnets for primary VPC in us-east-2
resource "aws_subnet" "primary_subnet_1" {
  provider = aws.us_east_2
  vpc_id = aws_vpc.primary_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-2a"
}

resource "aws_subnet" "primary_subnet_2" {
  provider = aws.us_east_2
  vpc_id = aws_vpc.primary_vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-2b"
}

# Read Replica VPC in us-west-2
resource "aws_vpc" "replica_vpc" {
  provider = aws.us_west_2
  cidr_block = "10.1.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = "replica-vpc"
  }
}

# Subnets for replica VPC in us-west-2
resource "aws_subnet" "replica_subnet_1" {
  provider = aws.us_west_2
  vpc_id = aws_vpc.replica_vpc.id
  cidr_block = "10.1.1.0/24"
  availability_zone = "us-west-2a"
}

resource "aws_subnet" "replica_subnet_2" {
  provider = aws.us_west_2
  vpc_id = aws_vpc.replica_vpc.id
  cidr_block = "10.1.2.0/24"
  availability_zone = "us-west-2b"
}

# Security Group for Primary DB in us-east-2
resource "aws_security_group" "primary_db_sg" {
  provider = aws.us_east_2
  vpc_id = aws_vpc.primary_vpc.id
  name = "primary-db-security-group"

  ingress {
    from_port = 5432
    to_port = 5432
    protocol = "tcp"
    cidr_blocks = [aws_vpc.replica_vpc.cidr_block]  # Allow replica region VPC to access
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group for Read Replica DB in us-west-2
resource "aws_security_group" "replica_db_sg" {
  provider = aws.us_west_2
  vpc_id = aws_vpc.replica_vpc.id
  name = "replica-db-security-group"

  ingress {
    from_port = 5432
    to_port = 5432
    protocol = "tcp"
    cidr_blocks = [aws_vpc.primary_vpc.cidr_block]  # Allow primary region VPC to access
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Subnet Group for Primary DB
resource "aws_db_subnet_group" "primary_db_subnet_group" {
  provider = aws.us_east_2
  name = "primary-db-subnet-group"
  subnet_ids = [
    aws_subnet.primary_subnet_1.id,
    aws_subnet.primary_subnet_2.id
  ]

  tags = {
    Name = "primary-db-subnet-group"
  }
}

# Primary PostgreSQL Database in us-east-2
resource "aws_db_instance" "primary_db" {
  provider = aws.us_east_2
  identifier = "primary-postgres-db"
  instance_class = "db.t3.micro"               # Choose instance type as needed
  allocated_storage = 20                       # Set storage as required
  engine = "postgres"
  engine_version = "16.4"                      # Choose PostgreSQL version
  username = "your_username"
  password = "your_password"
  db_subnet_group_name = aws_db_subnet_group.primary_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.primary_db_sg.id]
  multi_az = false
  publicly_accessible = false
  skip_final_snapshot = true
  backup_retention_period   = 7                         # Keep backups for 7 days
  backup_window             = "03:00-04:00"             # Optional: specify backup window
}

# Subnet Group for Replica DB
resource "aws_db_subnet_group" "replica_db_subnet_group" {
  provider = aws.us_west_2
  name = "replica-db-subnet-group"
  subnet_ids = [
    aws_subnet.replica_subnet_1.id,
    aws_subnet.replica_subnet_2.id
  ]

  tags = {
    Name = "replica-db-subnet-group"
  }
}

# Read Replica PostgreSQL Database in us-west-2
resource "aws_db_instance" "read_replica" {
  provider = aws.us_west_2
  identifier = "read-replica-postgres-db"
  instance_class = "db.t3.micro"               # Choose instance type as needed
  engine = "postgres"
  replicate_source_db = aws_db_instance.primary_db.arn
  publicly_accessible = false
  db_subnet_group_name = aws_db_subnet_group.replica_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.replica_db_sg.id]
}
