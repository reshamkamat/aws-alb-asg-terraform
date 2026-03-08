# AWS ALB + Auto Scaling Group using Terraform

This project deploys a highly available AWS architecture using Terraform.

## Services Used
- VPC
- Public and Private Subnets
- Internet Gateway
- Security Groups
- Application Load Balancer
- Target Group
- Launch Template
- Auto Scaling Group
- EC2 instances with nginx

## Architecture Flow
User -> ALB -> Target Group -> EC2 Instances

## Terraform Files
- providers.tf
- variables.tf
- main.tf
- outputs.tf

## Commands
terraform init
terraform plan
terraform apply
terraform destroy
