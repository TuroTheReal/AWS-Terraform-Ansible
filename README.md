# AWS-Terraform-Ansible

<p align="center">
  <img src="https://img.shields.io/badge/Status-Active-brightgreen.svg"/>
  <img src="https://img.shields.io/badge/Updated-2026--03-blue.svg"/>
  <img src="https://img.shields.io/badge/Difficulty-Intermediate-orange.svg"/>
</p>

<p align="center">
  <i>Infrastructure as Code: Automated WordPress deployment on AWS (Free-tier) using Terraform and Ansible</i>
</p>

---

## 📑 Table of Contents
- [📌 About](#-about)
- [⚠️ Architecture Constraints](#️-architecture-constraints)
- [🏗️ Infrastructure Diagram](#️-infrastructure-diagram)
- [📁 Content Structure](#-content-structure)
- [✅ Prerequisites](#-prerequisites)
- [🚀 Quick Start](#-quick-start)
- [⚙️ Configuration](#️-configuration)
- [📖 Usage Guide](#-usage-guide)
- [🔧 Troubleshooting](#-troubleshooting)
- [📝 Related Articles](#-related-articles)

## 📌 About

This project automatically deploys a complete WordPress infrastructure on AWS by combining:
- **Terraform** for cloud infrastructure provisioning
- **Ansible** for server configuration management
- **Docker** for service containerization

### Deployed Stack

| Service | Description |
|---------|-------------|
| WordPress | Containerized CMS |
| MariaDB | Database |
| Nginx | Reverse proxy |
| PHPMyAdmin | DB interface |
| WP-CLI | WordPress CLI management |

### Automated Workflow

```
terraform apply → EC2 created → Inventory generated → SSH ready → Ansible triggered → Docker installed → WordPress UP
```

## ⚠️ Architecture Constraints

### Current Setup (AWS Free Tier)

This project runs within **AWS Free Tier limits**:

| Resource | Configuration | Free Tier Limit |
|----------|---------------|-----------------|
| EC2 | t2.micro | 750h/month |
| Storage | 8GB EBS gp3 | 30GB/month |
| Database | MariaDB container | N/A (self-hosted) |
| TLS/HTTPS | Not available | Requires ALB |

**Limitations:**
- No load balancer (direct EC2 access)
- No shared database (each instance has its own MariaDB)
- HTTP only (HTTPS requires ALB + ACM)
- Dynamic IPs (no Elastic IP to stay free)
- PHPMyAdmin exposed publicly (development only — should be restricted or removed in production)

### Production Architecture

For production without Free Tier constraints:

```
                         ┌─────────────────┐
        HTTPS            │      ALB        │
Users ──────────────────▶│ + ACM (TLS)     │
                         └────────┬────────┘
                                  │
                    ┌─────────────┴─────────────┐
                    ▼                           ▼
              ┌───────────┐               ┌───────────┐
              │ ECS/EC2   │               │ ECS/EC2   │
              │ WordPress │               │ WordPress │
              └─────┬─────┘               └─────┬─────┘
                    │                           │
                    └─────────────┬─────────────┘
                                  ▼
                         ┌───────────────┐
                         │  RDS MySQL    │
                         │  (shared DB)  │
                         └───────────────┘
```

| Component | Free Tier | Production |
|-----------|-----------|------------|
| Compute | EC2 t2.micro | EC2 Auto Scaling Group or ECS Fargate |
| Load Balancer | None | ALB (TLS termination) |
| Database | MariaDB container | RDS MySQL (managed, backups, Multi-AZ) |
| TLS/HTTPS | None | ACM (free certificate) + ALB |
| Media Storage | Docker volume | S3 bucket |
| DNS | IP address | Route53 (optional) |

### Why This Matters

**Current project (2 independent EC2):**
- Each instance has its own database
- Data is NOT synchronized
- Users hitting different IPs see different content

**Production setup (ALB + shared RDS):**
- Single entry point (ALB DNS)
- All instances share the same database
- Consistent data across all requests
- Auto-scaling based on load

## 🏗️ Infrastructure Diagram

```mermaid
graph TB
    subgraph "AWS Cloud"
        subgraph "VPC - Default"
            SG[Security Group<br/>Ports: 22, 80]

            subgraph "EC2 Instance 1"
                D1[Docker]
                D1 --> WP1[WordPress]
                D1 --> DB1[MariaDB]
                D1 --> NG1[Nginx]
                D1 --> PMA1[PHPMyAdmin]
            end

            subgraph "EC2 Instance 2"
                D2[Docker]
                D2 --> WP2[WordPress]
                D2 --> DB2[MariaDB]
                D2 --> NG2[Nginx]
                D2 --> PMA2[PHPMyAdmin]
            end
        end
    end

    subgraph "Local Machine"
        TF[Terraform] -->|Provision| SG
        TF -->|Create| D1
        TF -->|Create| D2
        TF -->|Generate| INV[Inventory]
        INV --> ANS[Ansible]
        ANS -->|Configure| D1
        ANS -->|Configure| D2
    end

    USER[User] -->|HTTP :80| NG1
    USER -->|HTTP :80| NG2
```

## 📁 Content Structure

```
AWS-Terraform-Ansible/
├── terraform/
│   ├── main.tf              # AWS resources (EC2, SG, null_resource)
│   ├── variables.tf         # Terraform variables
│   ├── outputs.tf           # Outputs (public IPs)
│   └── inventory.tpl        # Ansible inventory template
├── ansible/
│   ├── inventory/
│   │   ├── group_vars/
│   │   │   └── all.yml.example  # Template — copy to all.yml and fill in
│   │   └── host.yml             # Inventory generated by Terraform
│   └── playbooks/
│       ├── templates/           # Jinja2 templates (docker-compose, nginx)
│       ├── 01-docker-installation.yml
│       └── 02-deploy-wordpress.yml
└── README.md
```

## ✅ Prerequisites

### Required Tools

| Tool | Version | Installation |
|------|---------|--------------|
| Terraform | >= 1.0 | [terraform.io](https://terraform.io) |
| Ansible | >= 2.9 | `pip install ansible` |
| AWS CLI | >= 2.0 | [aws.amazon.com/cli](https://aws.amazon.com/cli/) |

### AWS Configuration

```bash
# Configure credentials
aws configure

# Existing SSH key
ls ~/.ssh/aws  # Private key
# The "aws" key pair must exist on AWS
```

### Required Ansible Collection

```bash
ansible-galaxy collection install community.docker
```

### Ansible Variables File

Copy the example file and fill in your secrets:

```bash
cp ansible/inventory/group_vars/all.yml.example ansible/inventory/group_vars/all.yml
```

## 🚀 Quick Start

### Full Deployment (one-liner)

```bash
cd terraform && terraform init && terraform apply -auto-approve
```

### Step-by-step Deployment

```bash
# 1. Initialize Terraform
cd terraform
terraform init

# 2. Preview changes
terraform plan

# 3. Apply (creates EC2 + triggers Ansible automatically)
terraform apply
```

### Access Services

After deployment, retrieve the IPs:

```bash
terraform output
```

| Service | URL |
|---------|-----|
| WordPress | `http://<IP>/` |
| PHPMyAdmin | `http://<IP>/phpmyadmin/` |
| WP Admin | `http://<IP>/wp-admin/` |

## ⚙️ Configuration

### Terraform Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `aws_region` | `us-east-1` | AWS region |
| `instance_type` | `t3.micro` | Instance type |
| `key_name` | `aws` | SSH key pair name |
| `project_name` | `AWS-Terraform-Ansible` | Resource tagging |

**Override**: create `terraform.tfvars`

```hcl
aws_region    = "eu-west-1"
instance_type = "t2.micro"  # Free tier
```

### Ansible Variables

File: `ansible/inventory/group_vars/all.yml` (copied from `all.yml.example`)

| Variable | Description |
|----------|-------------|
| `wp_admin_user` | WordPress admin |
| `wp_admin_password` | Admin password |
| `wp_site_title` | Site title |
| `mysql_root_password` | MariaDB root |

## 📖 Usage Guide

### Run Ansible Only

```bash
cd ansible
ansible-playbook -i inventory/host.yml playbooks/01-docker-installation.yml
ansible-playbook -i inventory/host.yml playbooks/02-deploy-wordpress.yml
```

### Destroy Infrastructure

```bash
cd terraform
terraform destroy
```

### SSH to Instance

```bash
ssh -i ~/.ssh/aws ubuntu@<PUBLIC_IP>
```

### Check Containers

```bash
ssh -i ~/.ssh/aws ubuntu@<IP> "docker ps"
```

## 🔧 Troubleshooting

### SSH Timeout During Terraform

The `null_resource.wait_ssh` waits for SSH to be ready. If timeout occurs:
- Check Security Group (port 22 open)
- Verify SSH key matches AWS key pair

### Ansible Fails

```bash
# Test connection
ansible -i ansible/inventory/host.yml all -m ping

# Verbose mode
ansible-playbook -i inventory/host.yml playbooks/01-docker-installation.yml -vvv
```

### WordPress Unreachable

```bash
# Check containers
docker ps -a
docker logs wordpress
docker logs nginx
```

## 📝 Related Articles

Blog posts documenting the learning process and context behind this project:

- 📝 [AWS + Terraform + Ansible: Infrastructure as Code](https://arthur-portfolio.com/en/blog/aws-terraform-ansible) — Deep dive into this project: design choices, Free-tier constraints and automation workflow

---

**Last Updated**: 2026-03-25
**Version**: 1.0
