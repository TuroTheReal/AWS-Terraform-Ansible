all:
  hosts:
    aws_server:
      ansible_host: ${instance_ip}
      ansible_user: ubuntu
      ansible_ssh_private_key_file: ~/.ssh/aws