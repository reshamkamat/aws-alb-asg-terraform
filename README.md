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


# AWS ALB + Auto Scaling Group using Terraform

Architecture Diagram


                Internet
                    |
                    |
            +-------------------+
            | Application Load  |
            |     Balancer      |
            +-------------------+
                    |
                    |
               Target Group
                    |
        -----------------------------
        |                           |
+-------------------+       +-------------------+
|   EC2 Instance    |       |   EC2 Instance    |
|      (Nginx)      |       |      (Nginx)      |
+-------------------+       +-------------------+
         \                         /
          \                       /
           +---------------------+
           |   Auto Scaling      |
           |       Group         |
           +---------------------+





## Load Balancing Verification

The Application Load Balancer distributes incoming traffic across multiple EC2 instances.

### Response from Instance 1
![ALB Instance 1](images/alb-loadbalancer-instance1.png)

### Response from Instance 2
![ALB Instance 2](images/alb-loadbalancer-instance2.png)

Refreshing the browser returns different hostnames, demonstrating that the Application Load Balancer distributes traffic across instances in the Auto Scaling Group.
