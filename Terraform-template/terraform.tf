# Configure the AWS Provider
provider "aws" {
  region = "us-west-2" # Changed region to us-west-2
}

# Configure S3 Backend for Terraform State (Highly Recommended for production)
# You need to create this S3 bucket manually in us-west-2 before running terraform init
terraform {
  backend "s3" {
    bucket = "meghanavalluri-terraform" # <--- IMPORTANT: Replace with a unique S3 bucket name
    key    = "ecommerce-infra/terraform.tfstate"
    region = "us-west-2"
    encrypt = true
  }
}

# Parameters (Terraform variables)
variable "my_vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
  validation {
    condition     = contains(["10.0.0.0/16", "20.0.0.0/18"], var.my_vpc_cidr)
    error_message = "MyVpcCidr must be either '10.0.0.0/16' or '20.0.0.0/18'."
  }
}

variable "my_db_subnet_group_name" {
  description = "Name for the DB Subnet Group"
  type        = string
  default     = "mydbsubnetgroup" # Changed to lowercase to adhere to naming constraints
}

variable "my_db_name" {
  description = "Name for the MySQL Database"
  type        = string
  default     = "database-1"
}

variable "my_db_root_user_name" {
  description = "Root username for the MySQL Database"
  type        = string
  default     = "admin"
}

variable "my_db_root_user_password" {
  description = "Root password for the MySQL Database"
  type        = string
  default     = "strongpassword"
  sensitive   = true # Mark as sensitive to prevent logging
}

# Mappings (Terraform locals)
locals {
  subnet_config = {
    Vpc10 = {
      PublicSubnetAZ1CIDR  = "10.0.0.0/20"
      PrivateSubnetAZ1CIDR1 = "10.0.16.0/20"
      PrivateSubnetAZ1CIDR2 = "10.0.32.0/20"
      PublicSubnetAZ2CIDR  = "10.0.48.0/20"
      PrivateSubnetAZ2CIDR1 = "10.0.64.0/20"
      PrivateSubnetAZ2CIDR2 = "10.0.80.0/20"
    }
    Vpc20 = {
      PublicSubnetAZ1CIDR  = "20.0.0.0/22"
      PrivateSubnetAZ1CIDR1 = "20.0.4.0/22"
      PrivateSubnetAZ1CIDR2 = "20.0.8.0/22"
      PublicSubnetAZ2CIDR  = "20.0.12.0/22"
      PrivateSubnetAZ2CIDR1 = "20.0.16.0/22"
      PrivateSubnetAZ2CIDR2 = "20.0.20.0/22"
    }
  }

  selected_subnet_config = var.my_vpc_cidr == "10.0.0.0/16" ? local.subnet_config.Vpc10 : local.subnet_config.Vpc20
}

# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC
resource "aws_vpc" "my_vpc" {
  cidr_block           = var.my_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.my_db_name}-My-VPC" # Using my_db_name as a prefix for stack-like naming
  }
}

# Internet Gateway
resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "${var.my_db_name}-Internet-Gateway"
  }
}

# Public Subnets
resource "aws_subnet" "my_pub_sub1" {
  vpc_id                  = aws_vpc.my_vpc.id
  availability_zone       = data.aws_availability_zones.available.names[0]
  cidr_block              = local.selected_subnet_config.PublicSubnetAZ1CIDR
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.my_db_name}-Public-Subnet-AZ1"
  }
}

resource "aws_subnet" "my_pub_sub2" {
  vpc_id                  = aws_vpc.my_vpc.id
  availability_zone       = data.aws_availability_zones.available.names[1]
  cidr_block              = local.selected_subnet_config.PublicSubnetAZ2CIDR
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.my_db_name}-Public-Subnet-AZ2"
  }
}

# Private Subnets
resource "aws_subnet" "my_pri_sub1" {
  vpc_id                  = aws_vpc.my_vpc.id
  availability_zone       = data.aws_availability_zones.available.names[0]
  cidr_block              = local.selected_subnet_config.PrivateSubnetAZ1CIDR1
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.my_db_name}-Private-Subnet-1-AZ1"
  }
}

resource "aws_subnet" "my_pri_sub2" {
  vpc_id                  = aws_vpc.my_vpc.id
  availability_zone       = data.aws_availability_zones.available.names[0]
  cidr_block              = local.selected_subnet_config.PrivateSubnetAZ1CIDR2
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.my_db_name}-Private-Subnet-2-AZ1"
  }
}

resource "aws_subnet" "my_pri_sub3" {
  vpc_id                  = aws_vpc.my_vpc.id
  availability_zone       = data.aws_availability_zones.available.names[1]
  cidr_block              = local.selected_subnet_config.PrivateSubnetAZ2CIDR1
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.my_db_name}-Private-Subnet-1-AZ2"
  }
}

resource "aws_subnet" "my_pri_sub4" {
  vpc_id                  = aws_vpc.my_vpc.id
  availability_zone       = data.aws_availability_zones.available.names[1]
  cidr_block              = local.selected_subnet_config.PrivateSubnetAZ2CIDR2
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.my_db_name}-Private-Subnet-2-AZ2"
  }
}

# EIP for NAT Gateway
resource "aws_eip" "my_eip_for_nat" {

  tags = {
    Name = "${var.my_db_name}-NAT-EIP"
  }
}

# NAT Gateway
resource "aws_nat_gateway" "my_nat_gateway" {
  allocation_id = aws_eip.my_eip_for_nat.id
  subnet_id     = aws_subnet.my_pub_sub1.id

  tags = {
    Name = "${var.my_db_name}-NAT-Gateway"
  }
  depends_on = [aws_internet_gateway.my_igw] # Ensure IGW is attached before NAT GW is created
}

# Public Route Table
resource "aws_route_table" "my_pub_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "${var.my_db_name}-Public-RT"
  }
}

# Private Route Table
resource "aws_route_table" "my_pri_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "${var.my_db_name}-Private-RT"
  }
}

# Public Route Table Associations
resource "aws_route_table_association" "my_pub_rt_assoc1" {
  subnet_id      = aws_subnet.my_pub_sub1.id
  route_table_id = aws_route_table.my_pub_route_table.id
}

resource "aws_route_table_association" "my_pub_rt_assoc2" {
  subnet_id      = aws_subnet.my_pub_sub2.id
  route_table_id = aws_route_table.my_pub_route_table.id
}

# Private Route Table Associations
resource "aws_route_table_association" "my_pri_rt_assoc1" {
  subnet_id      = aws_subnet.my_pri_sub1.id
  route_table_id = aws_route_table.my_pri_route_table.id
}

resource "aws_route_table_association" "my_pri_rt_assoc2" {
  subnet_id      = aws_subnet.my_pri_sub2.id
  route_table_id = aws_route_table.my_pri_route_table.id
}

resource "aws_route_table_association" "my_pri_rt_assoc3" {
  subnet_id      = aws_subnet.my_pri_sub3.id
  route_table_id = aws_route_table.my_pri_route_table.id
}

resource "aws_route_table_association" "my_pri_rt_assoc4" {
  subnet_id      = aws_subnet.my_pri_sub4.id
  route_table_id = aws_route_table.my_pri_route_table.id
}

# Public Default Route
resource "aws_route" "my_pub_default_route" {
  route_table_id         = aws_route_table.my_pub_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.my_igw.id
  depends_on             = [aws_internet_gateway.my_igw]
}

# Private Default Route
resource "aws_route" "my_pri_default_route" {
  route_table_id         = aws_route_table.my_pri_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.my_nat_gateway.id
  depends_on             = [aws_nat_gateway.my_nat_gateway]
}

# Database Security Group
resource "aws_security_group" "my_dbsg" {
  name_prefix = "${var.my_db_name}-DB-SG-"
  description = "Database SG"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.my_db_name}-DB-SG"
  }
}

# DB Subnet Group
resource "aws_db_subnet_group" "my_db_subnet_group" {
  name        = var.my_db_subnet_group_name
  description = "Subnets for MySQL"
  subnet_ids  = [
    aws_subnet.my_pri_sub1.id,
    aws_subnet.my_pri_sub2.id,
    aws_subnet.my_pri_sub3.id,
    aws_subnet.my_pri_sub4.id
  ]

  tags = {
    Name = "${var.my_db_name}-DBSubnetGroup"
  }
}

# RDS MySQL Database
resource "aws_db_instance" "mysql_database" {
  identifier            = var.my_db_name
  engine                = "mysql"
  engine_version        = "8.0.41"
  instance_class        = "db.t3.small"
  allocated_storage     = 20
  username              = var.my_db_root_user_name
  password              = var.my_db_root_user_password
  multi_az              = true
  publicly_accessible   = true
  vpc_security_group_ids = [aws_security_group.my_dbsg.id]
  db_subnet_group_name  = aws_db_subnet_group.my_db_subnet_group.name
  skip_final_snapshot   = true
  apply_immediately     = true

  tags = {
    Name = "${var.my_db_name}-SQLDatabase"
  }
}

# EKS Cluster IAM Role
resource "aws_iam_role" "eks_cluster_role" {
  name = "${var.my_db_name}-EKSClusterRole" # Made role name dynamic

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      },
    ]
  })

  tags = {
    Name = "${var.my_db_name}-EKSCluster-Role"
  }
}

# EKS Node Group IAM Role
resource "aws_iam_role" "eks_node_group_role" {
  name = "${var.my_db_name}-EKSNodeGroupRole" # Made role name dynamic

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      },
    ]
  })

  tags = {
    Name = "${var.my_db_name}-EKS-NodeGroupRole"
  }
}

# EKS Node Group Inline Policy (moved from aws_iam_role.eks_node_group_role)
resource "aws_iam_role_policy" "eks_node_group_inline_policy" {
  name   = "EKSNodeGroupPolicy"
  role   = aws_iam_role.eks_node_group_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:RunInstances",
          "ec2:DescribeInstances",
          "eks:DescribeNodegroup",
          "eks:CreateNodegroup",
          "eks:DeleteNodegroup",
          "ec2:AttachVolume",
          "ec2:CreateTags",
          "ec2:TerminateInstances"
        ]
        Resource = "*"
      },
    ]
  })
}

# EKS Cluster Security Group (for EKS ENIs)
resource "aws_security_group" "eks_cluster_sg" {
  name_prefix = "${var.my_db_name}-EKS-Cluster-SG-"
  description = "Security group for EKS cluster ENIs"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_vpc.my_vpc.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.my_db_name}-EKSCluster-SG"
  }
}


# EKS Cluster
resource "aws_eks_cluster" "my_eks_cluster" {
  name     = "eks-cluster-2"
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids         = [
      aws_subnet.my_pub_sub1.id,
      aws_subnet.my_pub_sub2.id,
      aws_subnet.my_pri_sub1.id,
      aws_subnet.my_pri_sub2.id,
      aws_subnet.my_pri_sub3.id,
      aws_subnet.my_pri_sub4.id,
    ]
    security_group_ids = [aws_security_group.eks_cluster_sg.id]
  }

  tags = {
    Name = "${var.my_db_name}-EksCluster"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy_attach_eks,
    aws_iam_role_policy_attachment.eks_cluster_policy_attach_vpc
  ]
}

# Attach managed policies to EKS Cluster Role (explicitly for Terraform)
resource "aws_iam_role_policy_attachment" "eks_cluster_policy_attach_eks" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy_attach_vpc" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
}

# Attach managed policies to EKS Node Group Role (explicitly for Terraform)
resource "aws_iam_role_policy_attachment" "eks_node_group_policy_attach_worker" {
  role       = aws_iam_role.eks_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_node_group_policy_attach_cni" {
  role       = aws_iam_role.eks_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "eks_node_group_policy_attach_ecr_read" {
  role       = aws_iam_role.eks_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "eks_node_group_policy_attach_ecr_pull" {
  role       = aws_iam_role.eks_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
}

resource "aws_iam_role_policy_attachment" "eks_node_group_policy_attach_ssm" {
  role       = aws_iam_role.eks_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# EKS Node Group
resource "aws_eks_node_group" "my_node_group" {
  cluster_name    = aws_eks_cluster.my_eks_cluster.name
  node_role_arn   = aws_iam_role.eks_node_group_role.arn
  subnet_ids      = [
    aws_subnet.my_pub_sub1.id,
    aws_subnet.my_pub_sub2.id,
    aws_subnet.my_pri_sub1.id,
    aws_subnet.my_pri_sub2.id,
    aws_subnet.my_pri_sub3.id,
    aws_subnet.my_pri_sub4.id,
  ]
  scaling_config {
    min_size     = 2
    max_size     = 5
    desired_size = 4
  }
  instance_types = ["t3.medium"]

  tags = {
    Name = "${var.my_db_name}-Node-group"
  }

  depends_on = [
    aws_eks_cluster.my_eks_cluster,
    aws_iam_role_policy_attachment.eks_node_group_policy_attach_worker,
    aws_iam_role_policy_attachment.eks_node_group_policy_attach_cni,
    aws_iam_role_policy_attachment.eks_node_group_policy_attach_ecr_read,
    aws_iam_role_policy_attachment.eks_node_group_policy_attach_ecr_pull,
    aws_iam_role_policy_attachment.eks_node_group_policy_attach_ssm,
    aws_iam_role_policy.eks_node_group_inline_policy # Added dependency on the new inline policy resource
  ]
}

# ECR Repository
resource "aws_ecr_repository" "ecommerce_flask_ecr" {
  name                 = "ecommerce-flask"
  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.my_db_name}-ecommerce-flask-ecr"
  }
}

# Outputs
output "rds_instance_endpoint" {
  description = "RDS Endpoint for MySQL Database"
  value       = aws_db_instance.mysql_database.address
}

output "ecommerce_flask_ecr_repository_uri" {
  description = "URI of the ecommerce-flask ECR repository"
  value       = aws_ecr_repository.ecommerce_flask_ecr.repository_url
}
