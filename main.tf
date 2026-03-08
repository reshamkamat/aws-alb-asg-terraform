data "aws_availability_zones" "available" {}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)

  tags = {
    Project = var.project_name
    Managed = "terraform"
  }
}

# -------------------------
# 1) VPC (2 AZ, public + private, NAT)
# -------------------------
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.project_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = local.azs
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.11.0/24", "10.0.12.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = local.tags
}

# -------------------------
# 2) Security Groups
# -------------------------

# ALB SG: allow HTTP from internet
module "alb_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "${var.project_name}-alb-sg"
  description = "ALB allows HTTP from internet"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["http-80-tcp"]

  egress_rules = ["all-all"]

  tags = local.tags
}

# EC2 SG: allow HTTP ONLY from ALB SG, optional SSH from your IP
resource "aws_security_group" "ec2_sg" {
  name        = "${var.project_name}-ec2-sg"
  description = "EC2 allows HTTP only from ALB"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [module.alb_sg.security_group_id]
  }

  # OPTIONAL: replace with your public IP like 1.2.3.4/32
  # ingress {
  #   description = "SSH from my IP"
  #   from_port   = 22
  #   to_port     = 22
  #   protocol    = "tcp"
  #   cidr_blocks = ["YOUR_IP/32"]
  # }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

# -------------------------
# 3) ALB + Target Group
# -------------------------
module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 9.0"

  name               = "${var.project_name}-alb"
  load_balancer_type = "application"
  vpc_id             = module.vpc.vpc_id
  subnets            = module.vpc.public_subnets
  security_groups    = [module.alb_sg.security_group_id]

  # Listener on 80
  listeners = {
    http = {
      port     = 80
      protocol = "HTTP"

      forward = {
        target_group_key = "web"
      }
    }
  }

  # Target group for ASG instances
  target_groups = {
    web = {
      name_prefix = "web-"
      protocol    = "HTTP"
      port        = 80
      target_type = "instance"
       create_attachment = false
      health_check = {
        path                = "/"
        healthy_threshold   = 2
        unhealthy_threshold = 2
        timeout             = 5
        interval            = 15
        matcher             = "200-399"
      }
    }
  }

  tags = local.tags
}

# -------------------------
# 4) Launch Template + ASG
# -------------------------
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_launch_template" "web" {
  name_prefix   = "${var.project_name}-lt-"
  image_id      = data.aws_ami.al2023.id
  instance_type = "t3.micro"

  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    dnf update -y
    dnf install -y nginx
    systemctl enable nginx
    INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
    HOSTNAME=$(hostname)
    cat > /usr/share/nginx/html/index.html <<HTML
    <html>
      <body style="font-family: Arial;">
        <h1>Terraform Project 2: ALB + ASG Working</h1>
        <p><b>Instance ID:</b> $INSTANCE_ID</p>
        <p><b>Hostname:</b> $HOSTNAME</p>
      </body>
    </html>
    HTML
    systemctl start nginx
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags          = merge(local.tags, { Name = "${var.project_name}-ec2" })
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "web" {
  name                      = "${var.project_name}-asg"
  desired_capacity          = 2
  min_size                  = 1
  max_size                  = 4
  vpc_zone_identifier       = module.vpc.private_subnets
  health_check_type         = "ELB"
  health_check_grace_period = 120

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  target_group_arns = [module.alb.target_groups["web"].arn]

  tag {
    key                 = "Name"
    value               = "${var.project_name}-asg-instance"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

# -------------------------
# 5) Auto Scaling policy (target tracking CPU 50%)
# -------------------------
resource "aws_autoscaling_policy" "cpu_target" {
  name                   = "${var.project_name}-cpu50"
  autoscaling_group_name = aws_autoscaling_group.web.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 50.0
  }
}
