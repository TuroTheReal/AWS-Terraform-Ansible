provider "aws" {
  region = var.aws_region
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]  # Canonical (fournisseur Ubuntu)

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "wordpress_sg" {
  name        = "cloud-1-wordpress-sg" 
  description = "Security group for WordPress server"

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # WordPress
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # PHPMyAdmin
  ingress {
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Autoriser tout en sortie
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "WordPress-SG"
    Project = var.project_name
  }
}

resource "aws_instance" "wordpress_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.wordpress_sg.id]

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
  }

  tags = {
    Name    = "WordPress-Server"
    Project = var.project_name
  }
}

# Générer inventory Ansible
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/inventory.tpl", {
    instance_ip = aws_instance.wordpress_server.public_ip
  })
  filename = "${path.module}/../ansible/inventory/aws.yml"
}

# Automatiser Ansible
resource "null_resource" "provision_wordpress" {
  depends_on = [
    aws_instance.wordpress_server,
    local_file.ansible_inventory
  ]

  # Attendre SSH
  provisioner "local-exec" {
    command = <<-EOT
      echo "Attente SSH..."
      until ssh -i ~/.ssh/aws -o ConnectTimeout=2 -o StrictHostKeyChecking=no ubuntu@${aws_instance.wordpress_server.public_ip} exit 2>/dev/null; do
        sleep 5
      done
    EOT
  }

  # Lancer Ansible
  provisioner "local-exec" {
    command = <<-EOT
      cd ${path.module}/../ansible
      ansible-playbook -i inventory/aws.yml playbooks/01-docker-installation.yml
      ansible-playbook -i inventory/aws.yml playbooks/02-deploy-wordpress.yml
    EOT
  }
}