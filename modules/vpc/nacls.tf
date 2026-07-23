# ------------------------------------------------------------------------------
# Network ACLs – tiered, explicit allow-list (defense in depth)
# NACLs are stateless: allow both directions for a flow (inbound + outbound).
# Rule numbers have gaps (10, 20, ...) so you can insert rules later.
# Controlled by var.enable_nacls (default true). Set false to use VPC default NACL.
# ------------------------------------------------------------------------------
locals {
  # Ephemeral port range for return traffic (NAT, load balancers, app connections)
  ephemeral_from = 1024
  ephemeral_to   = 65535
  # Tier-level CIDRs (one /23 per tier for 2 AZs) to stay under NACL 20-rule-per-direction limit
  # Public:  index 0,1 → 10.0.0.0/23; Backend: 2,3 → 10.0.2.0/23; Data: 4,5 → 10.0.4.0/23
  public_tier_cidr  = cidrsubnet(var.vpc_cidr, 7, 0)
  backend_tier_cidr = cidrsubnet(var.vpc_cidr, 7, 1)
  data_tier_cidr    = cidrsubnet(var.vpc_cidr, 7, 2)
}

# ------------------------------------------------------------------------------
# Public subnet NACL – Internet-facing
# ------------------------------------------------------------------------------

resource "aws_network_acl" "public" {
  count = var.enable_nacls ? 1 : 0

  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.public[*].id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-public"
    Tier = "public"
  })
}

resource "aws_network_acl_rule" "public_in_ports" {
  count = var.enable_nacls ? length(var.public_inbound_ports) : 0

  network_acl_id = aws_network_acl.public[0].id
  rule_number    = 10 + count.index
  rule_action    = "allow"
  protocol       = "tcp"
  cidr_block     = "0.0.0.0/0"
  from_port      = var.public_inbound_ports[count.index]
  to_port        = var.public_inbound_ports[count.index]
  egress         = false
}

resource "aws_network_acl_rule" "public_in_ephemeral" {
  count          = var.enable_nacls ? 1 : 0
  network_acl_id = aws_network_acl.public[0].id
  rule_number    = 50
  rule_action    = "allow"
  protocol       = "tcp"
  cidr_block     = "0.0.0.0/0"
  from_port      = local.ephemeral_from
  to_port        = local.ephemeral_to
  egress         = false
}

resource "aws_network_acl_rule" "public_in_vpc" {
  count          = var.enable_nacls ? 1 : 0
  network_acl_id = aws_network_acl.public[0].id
  rule_number    = 60
  rule_action    = "allow"
  protocol       = -1
  cidr_block     = aws_vpc.main.cidr_block
  egress         = false
}

resource "aws_network_acl_rule" "public_out_ports" {
  count = var.enable_nacls ? length(var.public_inbound_ports) : 0

  network_acl_id = aws_network_acl.public[0].id
  rule_number    = 10 + count.index
  rule_action    = "allow"
  protocol       = "tcp"
  cidr_block     = "0.0.0.0/0"
  from_port      = var.public_inbound_ports[count.index]
  to_port        = var.public_inbound_ports[count.index]
  egress         = true
}

resource "aws_network_acl_rule" "public_out_ephemeral" {
  count          = var.enable_nacls ? 1 : 0
  network_acl_id = aws_network_acl.public[0].id
  rule_number    = 50
  rule_action    = "allow"
  protocol       = "tcp"
  cidr_block     = "0.0.0.0/0"
  from_port      = local.ephemeral_from
  to_port        = local.ephemeral_to
  egress         = true
}

# Outbound: DNS (UDP 53) – NAT gateway forwards DNS queries from backend tasks
resource "aws_network_acl_rule" "public_out_dns_udp" {
  count          = var.enable_nacls ? 1 : 0
  network_acl_id = aws_network_acl.public[0].id
  rule_number    = 51
  rule_action    = "allow"
  protocol       = "udp"
  cidr_block     = "0.0.0.0/0"
  from_port      = 53
  to_port        = 53
  egress         = true
}

# Inbound: UDP ephemeral – DNS response return traffic via NAT gateway
resource "aws_network_acl_rule" "public_in_dns_udp_return" {
  count          = var.enable_nacls ? 1 : 0
  network_acl_id = aws_network_acl.public[0].id
  rule_number    = 51
  rule_action    = "allow"
  protocol       = "udp"
  cidr_block     = "0.0.0.0/0"
  from_port      = local.ephemeral_from
  to_port        = local.ephemeral_to
  egress         = false
}

resource "aws_network_acl_rule" "public_out_vpc" {
  count          = var.enable_nacls ? 1 : 0
  network_acl_id = aws_network_acl.public[0].id
  rule_number    = 60
  rule_action    = "allow"
  protocol       = -1
  cidr_block     = aws_vpc.main.cidr_block
  egress         = true
}

# ------------------------------------------------------------------------------
# Backend subnet NACL – App tier (ECS, app servers)
# ------------------------------------------------------------------------------

resource "aws_network_acl" "backend" {
  count = var.enable_nacls ? 1 : 0

  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.backend[*].id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-backend"
    Tier = "backend"
  })
}

# Inbound: from public (ALB) on app ports and ephemeral; from VPC (self); from data (return); ephemeral from internet (NAT return)
resource "aws_network_acl_rule" "backend_in_public_app" {
  count = var.enable_nacls ? length(var.backend_app_ports) : 0

  network_acl_id = aws_network_acl.backend[0].id
  rule_number    = 10 + count.index
  rule_action    = "allow"
  protocol       = "tcp"
  cidr_block     = local.public_tier_cidr
  from_port      = var.backend_app_ports[count.index]
  to_port        = var.backend_app_ports[count.index]
  egress         = false
}

resource "aws_network_acl_rule" "backend_in_public_ephemeral" {
  count          = var.enable_nacls ? 1 : 0
  network_acl_id = aws_network_acl.backend[0].id
  rule_number    = 50
  rule_action    = "allow"
  protocol       = "tcp"
  cidr_block     = local.public_tier_cidr
  from_port      = local.ephemeral_from
  to_port        = local.ephemeral_to
  egress         = false
}

resource "aws_network_acl_rule" "backend_in_self" {
  count          = var.enable_nacls ? 1 : 0
  network_acl_id = aws_network_acl.backend[0].id
  rule_number    = 60
  rule_action    = "allow"
  protocol       = -1
  cidr_block     = aws_vpc.main.cidr_block
  egress         = false
}

resource "aws_network_acl_rule" "backend_in_data_ephemeral" {
  count          = var.enable_nacls ? 1 : 0
  network_acl_id = aws_network_acl.backend[0].id
  rule_number    = 70
  rule_action    = "allow"
  protocol       = "tcp"
  cidr_block     = local.data_tier_cidr
  from_port      = local.ephemeral_from
  to_port        = local.ephemeral_to
  egress         = false
}

resource "aws_network_acl_rule" "backend_in_ephemeral_internet" {
  count          = var.enable_nacls ? 1 : 0
  network_acl_id = aws_network_acl.backend[0].id
  rule_number    = 80
  rule_action    = "allow"
  protocol       = "tcp"
  cidr_block     = "0.0.0.0/0"
  from_port      = local.ephemeral_from
  to_port        = local.ephemeral_to
  egress         = false
}

# Outbound: HTTPS to internet (AWS APIs via NAT: CloudWatch, ECR, Secrets Manager, etc.)
resource "aws_network_acl_rule" "backend_out_http" {
  count          = var.enable_nacls ? 1 : 0
  network_acl_id = aws_network_acl.backend[0].id
  rule_number    = 4
  rule_action    = "allow"
  protocol       = "tcp"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
  egress         = true
}

resource "aws_network_acl_rule" "backend_out_https" {
  count          = var.enable_nacls ? 1 : 0
  network_acl_id = aws_network_acl.backend[0].id
  rule_number    = 5
  rule_action    = "allow"
  protocol       = "tcp"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
  egress         = true
}

# Outbound: DNS (UDP 53) to internet – needed for ACME DNS-01 propagation checks
resource "aws_network_acl_rule" "backend_out_dns_udp" {
  count          = var.enable_nacls ? 1 : 0
  network_acl_id = aws_network_acl.backend[0].id
  rule_number    = 6
  rule_action    = "allow"
  protocol       = "udp"
  cidr_block     = "0.0.0.0/0"
  from_port      = 53
  to_port        = 53
  egress         = true
}

# Inbound: UDP ephemeral return traffic from internet (DNS responses, etc.)
resource "aws_network_acl_rule" "backend_in_udp_ephemeral" {
  count          = var.enable_nacls ? 1 : 0
  network_acl_id = aws_network_acl.backend[0].id
  rule_number    = 81
  rule_action    = "allow"
  protocol       = "udp"
  cidr_block     = "0.0.0.0/0"
  from_port      = local.ephemeral_from
  to_port        = local.ephemeral_to
  egress         = false
}

# Outbound: to data (DB ports), to internet (ephemeral via NAT), to self
resource "aws_network_acl_rule" "backend_out_data_db" {
  count = var.enable_nacls ? length(var.data_ports) : 0

  network_acl_id = aws_network_acl.backend[0].id
  rule_number    = 10 + count.index
  rule_action    = "allow"
  protocol       = "tcp"
  cidr_block     = local.data_tier_cidr
  from_port      = var.data_ports[count.index]
  to_port        = var.data_ports[count.index]
  egress         = true
}

resource "aws_network_acl_rule" "backend_out_ephemeral" {
  count          = var.enable_nacls ? 1 : 0
  network_acl_id = aws_network_acl.backend[0].id
  rule_number    = 50
  rule_action    = "allow"
  protocol       = "tcp"
  cidr_block     = "0.0.0.0/0"
  from_port      = local.ephemeral_from
  to_port        = local.ephemeral_to
  egress         = true
}

resource "aws_network_acl_rule" "backend_out_vpc" {
  count          = var.enable_nacls ? 1 : 0
  network_acl_id = aws_network_acl.backend[0].id
  rule_number    = 60
  rule_action    = "allow"
  protocol       = -1
  cidr_block     = aws_vpc.main.cidr_block
  egress         = true
}

# ------------------------------------------------------------------------------
# Data subnet NACL – DB tier (RDS, ElastiCache, etc.)
# ------------------------------------------------------------------------------

resource "aws_network_acl" "data" {
  count = var.enable_nacls ? 1 : 0

  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.data[*].id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-data"
    Tier = "data"
  })
}

# Inbound: from backend only on DB ports and ephemeral (return)
resource "aws_network_acl_rule" "data_in_from_backend_db" {
  count = var.enable_nacls ? length(var.data_ports) : 0

  network_acl_id = aws_network_acl.data[0].id
  rule_number    = 10 + count.index
  rule_action    = "allow"
  protocol       = "tcp"
  cidr_block     = local.backend_tier_cidr
  from_port      = var.data_ports[count.index]
  to_port        = var.data_ports[count.index]
  egress         = false
}

resource "aws_network_acl_rule" "data_in_from_backend_ephemeral" {
  count          = var.enable_nacls ? 1 : 0
  network_acl_id = aws_network_acl.data[0].id
  rule_number    = 50
  rule_action    = "allow"
  protocol       = "tcp"
  cidr_block     = local.backend_tier_cidr
  from_port      = local.ephemeral_from
  to_port        = local.ephemeral_to
  egress         = false
}

# Inbound: return traffic from internet (source port 443) when data subnets use NAT
resource "aws_network_acl_rule" "data_in_ephemeral_internet" {
  count = var.enable_nacls && var.data_subnets_use_nat ? 1 : 0

  network_acl_id = aws_network_acl.data[0].id
  rule_number    = 55
  rule_action    = "allow"
  protocol       = "tcp"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
  egress         = false
}

# Outbound: ephemeral to backend (return traffic); optionally to internet if data has NAT
resource "aws_network_acl_rule" "data_out_ephemeral" {
  count          = var.enable_nacls ? 1 : 0
  network_acl_id = aws_network_acl.data[0].id
  rule_number    = 10
  rule_action    = "allow"
  protocol       = "tcp"
  cidr_block     = aws_vpc.main.cidr_block
  from_port      = local.ephemeral_from
  to_port        = local.ephemeral_to
  egress         = true
}

# Outbound: HTTPS to internet (image pull, APIs) when data subnets use NAT
resource "aws_network_acl_rule" "data_out_https" {
  count = var.enable_nacls && var.data_subnets_use_nat ? 1 : 0

  network_acl_id = aws_network_acl.data[0].id
  rule_number    = 15
  rule_action    = "allow"
  protocol       = "tcp"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
  egress         = true
}

resource "aws_network_acl_rule" "data_out_ephemeral_internet" {
  count = var.enable_nacls && var.data_subnets_use_nat ? 1 : 0

  network_acl_id = aws_network_acl.data[0].id
  rule_number    = 20
  rule_action    = "allow"
  protocol       = "tcp"
  cidr_block     = "0.0.0.0/0"
  from_port      = local.ephemeral_from
  to_port        = local.ephemeral_to
  egress         = true
}
