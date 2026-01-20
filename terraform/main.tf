provider "aws" {
  region = var.aws_region
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

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

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
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
    Name    = "WordPress-SG"
    Project = var.project_name
  }
}

resource "aws_instance" "wordpress_server" {
  count = 2

  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.wordpress_sg.id]

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
  }

  tags = {
    Name    = "WordPress-Server-${count.index + 1}"
    Project = var.project_name
  }
}

resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/inventory.tpl", {
    instance_ips = aws_instance.wordpress_server[*].public_ip
  })
  filename = "${path.module}/../ansible/inventory/aws.yml"
}

resource "null_resource" "wait_ssh" {
  count = 2

  depends_on = [
    aws_instance.wordpress_server,
    local_file.ansible_inventory
  ]

  provisioner "local-exec" {
    command = <<-EOT
      echo "Attente SSH instance ${count.index + 1}..."
      until ssh -i ~/.ssh/aws -o ConnectTimeout=2 -o StrictHostKeyChecking=no ubuntu@${aws_instance.wordpress_server[count.index].public_ip} exit 2>/dev/null; do
        sleep 5
      done
    EOT
  }
}

resource "null_resource" "run_ansible" {
  depends_on = [null_resource.wait_ssh]

  provisioner "local-exec" {
    command = <<-EOT
      cd ${path.module}/../ansible
      ansible-playbook -i inventory/aws.yml playbooks/01-docker-installation.yml
      ansible-playbook -i inventory/aws.yml playbooks/02-deploy-wordpress.yml
    EOT
  }
}