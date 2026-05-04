resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = merge(var.common_tags, { Name = "todo-${var.env}" })
}

resource "aws_subnet" "public" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false
  tags                    = merge(var.common_tags, { Name = "todo-${var.env}-public-${count.index}" })
}

# Private subnets for ECS tasks and EFS mount targets.
# CIDR offset +10 leaves room for future public subnets (e.g. NLB, bastion).
resource "aws_subnet" "private" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = var.availability_zones[count.index]
  tags              = merge(var.common_tags, { Name = "todo-${var.env}-private-${count.index}" })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = merge(var.common_tags, { Name = "todo-${var.env}-igw" })
}

locals {
  nat_count = var.single_nat_gateway ? 1 : length(var.availability_zones)
}

resource "aws_eip" "nat" {
  count      = local.nat_count
  domain     = "vpc"
  depends_on = [aws_internet_gateway.main]
  tags       = merge(var.common_tags, { Name = "todo-${var.env}-nat-eip-${count.index}" })
}

resource "aws_nat_gateway" "main" {
  count         = local.nat_count
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags          = merge(var.common_tags, { Name = "todo-${var.env}-nat-${count.index}" })
  depends_on    = [aws_internet_gateway.main]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = merge(var.common_tags, { Name = "todo-${var.env}-public-rt" })
}

resource "aws_route_table" "private" {
  count  = length(var.availability_zones)
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = var.single_nat_gateway ? aws_nat_gateway.main[0].id : aws_nat_gateway.main[count.index].id
  }
  tags = merge(var.common_tags, { Name = "todo-${var.env}-private-rt-${count.index}" })
}

resource "aws_route_table_association" "public" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# ── Security groups ───────────────────────────────────────────────────────────

resource "aws_security_group" "alb" {
  name        = "todo-${var.env}-alb"
  description = "Allow public HTTP to the ALB"
  vpc_id      = aws_vpc.main.id
  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Port 8080 is the CodeDeploy test listener — routes to green (new) tasks
  # before production traffic shifts, enabling smoke-test validation.
  ingress {
    description = "CodeDeploy test listener from internet"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # ALB only needs to reach ECS tasks on their container ports (private subnets).
  egress {
    description = "Forward to frontend tasks"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }
  egress {
    description = "Forward to backend tasks"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }
  tags = merge(var.common_tags, { Name = "todo-${var.env}-alb-sg" })
}

resource "aws_security_group" "backend" {
  name        = "todo-${var.env}-backend"
  description = "Allow traffic from the ALB to the backend task only"
  vpc_id      = aws_vpc.main.id
  ingress {
    description     = "Flask from ALB"
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  # HTTPS to 0.0.0.0/0 is required: Fargate pulls images from ECR and reads
  # secrets from Secrets Manager via the NAT gateway. VPC endpoints would
  # eliminate this but cost ~$7/month each; accepted for non-prod environments.
  egress {
    description = "HTTPS to AWS APIs (ECR, Secrets Manager, CloudWatch) via NAT"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "PostgreSQL to RDS (private subnet)"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }
  tags = merge(var.common_tags, { Name = "todo-${var.env}-backend-sg" })
}

resource "aws_security_group" "frontend" {
  name        = "todo-${var.env}-frontend"
  description = "Allow traffic from the ALB to the frontend task only"
  vpc_id      = aws_vpc.main.id
  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  # HTTPS egress required for Fargate to pull images from ECR and write
  # logs to CloudWatch via the NAT gateway.
  egress {
    description = "HTTPS to AWS APIs (ECR, CloudWatch) via NAT"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(var.common_tags, { Name = "todo-${var.env}-frontend-sg" })
}

# ── Application Load Balancer ─────────────────────────────────────────────────

resource "aws_lb" "main" {
  name                       = "todo-${var.env}"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb.id]
  subnets                    = aws_subnet.public[*].id
  drop_invalid_header_fields = true
  tags                       = merge(var.common_tags, { Name = "todo-${var.env}-alb" })
}

resource "aws_lb_target_group" "backend" {
  name        = "todo-${var.env}-backend"
  port        = 5000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"
  health_check {
    path                = "/api/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
  }
  tags = var.common_tags
}

resource "aws_lb_target_group" "frontend" {
  name        = "todo-${var.env}-frontend"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"
  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
  }
  tags = var.common_tags
}

# ── Green (CodeDeploy) target groups ─────────────────────────────────────────
# Blue TGs (above) hold production traffic initially.
# CodeDeploy routes new tasks to these green TGs and shifts traffic gradually.

resource "aws_lb_target_group" "backend_green" {
  name        = "todo-${var.env}-backend-green"
  port        = 5000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"
  health_check {
    path                = "/api/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
  }
  tags = var.common_tags
}

resource "aws_lb_target_group" "frontend_green" {
  name        = "todo-${var.env}-frontend-green"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"
  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
  }
  tags = var.common_tags
}

# ── Production listener (blue) ────────────────────────────────────────────────

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

resource "aws_lb_listener_rule" "api" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10
  condition {
    path_pattern { values = ["/api/*"] }
  }
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}

# ── Test listener (green) — CodeDeploy routes here before traffic shift ───────

resource "aws_lb_listener" "test" {
  load_balancer_arn = aws_lb.main.arn
  port              = 8080
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend_green.arn
  }
}

resource "aws_lb_listener_rule" "api_test" {
  listener_arn = aws_lb_listener.test.arn
  priority     = 10
  condition {
    path_pattern { values = ["/api/*"] }
  }
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_green.arn
  }
}
