# ------------------------------------------------------------------------------
# VPC and core networking: public, backend, and data tiers
# ------------------------------------------------------------------------------

locals {
  az_count = length(var.availability_zones)
  # One subnet per AZ per tier; CIDRs from VPC block
  # Public:  index 0,1   Backend: 2,3   Data: 4,5
  public_subnet_cidrs  = [for i in range(local.az_count) : cidrsubnet(var.vpc_cidr, 8, i)]
  backend_subnet_cidrs = [for i in range(local.az_count) : cidrsubnet(var.vpc_cidr, 8, local.az_count + i)]
  data_subnet_cidrs    = [for i in range(local.az_count) : cidrsubnet(var.vpc_cidr, 8, 2 * local.az_count + i)]
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = var.name_prefix
  })
}

# ------------------------------------------------------------------------------
# VPC Flow Logs – capture network traffic metadata to CloudWatch Logs
# ------------------------------------------------------------------------------

resource "aws_flow_log" "main" {
  count = var.enable_flow_logs ? 1 : 0

  vpc_id               = aws_vpc.main.id
  traffic_type         = "ALL"
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.flow_logs[0].arn
  iam_role_arn         = aws_iam_role.flow_logs[0].arn

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-flow-logs"
  })
}

resource "aws_cloudwatch_log_group" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name              = "/vpc/${var.name_prefix}/flow-logs"
  retention_in_days = var.flow_logs_retention_days
  kms_key_id        = var.flow_logs_kms_key_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-flow-logs"
  })
}

resource "aws_iam_role" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name = "${var.name_prefix}-vpc-flow-logs"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name = "vpc-flow-logs"
  role = aws_iam_role.flow_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Resource = "${aws_cloudwatch_log_group.flow_logs[0].arn}:*"
    }]
  })
}

# ------------------------------------------------------------------------------
# Public subnets (ALB, NAT Gateway, bastion if any)
# ------------------------------------------------------------------------------

resource "aws_subnet" "public" {
  count = local.az_count

  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-public-${count.index + 1}"
    Tier = "public"
  })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-igw"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-public"
  })
}

resource "aws_route_table_association" "public" {
  count = local.az_count

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ------------------------------------------------------------------------------
# NAT Gateway(s): single for cost, or one per AZ for HA
# ------------------------------------------------------------------------------

resource "aws_eip" "nat" {
  count  = var.single_nat_gateway ? 1 : local.az_count
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-nat-eip-${count.index + 1}"
  })

  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main" {
  count = var.single_nat_gateway ? 1 : local.az_count

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-nat-${count.index + 1}"
  })
}

# ------------------------------------------------------------------------------
# Backend (private) subnets – ECS tasks, app servers
# ------------------------------------------------------------------------------

resource "aws_subnet" "backend" {
  count = local.az_count

  vpc_id            = aws_vpc.main.id
  cidr_block        = local.backend_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-backend-${count.index + 1}"
    Tier = "backend"
  })
}

resource "aws_route_table" "backend" {
  count = local.az_count

  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = var.single_nat_gateway ? aws_nat_gateway.main[0].id : aws_nat_gateway.main[count.index].id
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-backend-${count.index + 1}"
  })
}

resource "aws_route_table_association" "backend" {
  count = local.az_count

  subnet_id      = aws_subnet.backend[count.index].id
  route_table_id = aws_route_table.backend[count.index].id
}

# ------------------------------------------------------------------------------
# Data (private) subnets – RDS, ElastiCache, etc.
# ------------------------------------------------------------------------------

resource "aws_subnet" "data" {
  count = local.az_count

  vpc_id            = aws_vpc.main.id
  cidr_block        = local.data_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-data-${count.index + 1}"
    Tier = "data"
  })
}

resource "aws_route_table" "data" {
  count = local.az_count

  vpc_id = aws_vpc.main.id

  dynamic "route" {
    for_each = var.data_subnets_use_nat ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = var.single_nat_gateway ? aws_nat_gateway.main[0].id : aws_nat_gateway.main[count.index].id
    }
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-data-${count.index + 1}"
  })
}

resource "aws_route_table_association" "data" {
  count = local.az_count

  subnet_id      = aws_subnet.data[count.index].id
  route_table_id = aws_route_table.data[count.index].id
}
