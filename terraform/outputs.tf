output "instance_public_ip" {
	description = "Public IP address of the WordPress server"
	value = aws_instance.wordpress_server.public_ip
}

output "instance_private_ip" {
	description = "Private IP address of the WordPress server"
	value = aws_instance.wordpress_server.private_ip
}

output "instance_id" {
	description = "Id of the WordPress server"
	value = aws_instance.wordpress_server.id
}

output "instance_public_dns" {
	description = "Public DNS of the WordPress server"
	value = aws_instance.wordpress_server.public_dns
}