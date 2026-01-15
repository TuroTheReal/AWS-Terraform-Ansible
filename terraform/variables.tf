variable "aws_region" {
	description = "AWS deployment region"
	type		= string
	default		= "us-east-1"
}

variable "instance_type" {
	description = "EC2 Instance type (FREE TIER = t2.micro)"
	type		= string
	default 	= "t3.micro"
}

variable "project_name" {
	description = "Project name for resource tagging"
	type		= string
	default		= "AWS-Terraform-Ansible"
}

variable "key_name" {
	description = "AWS SSH key pair name"
	type 		= string
	default 	= "aws"
}
