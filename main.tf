/*

provider "aws" {
  region = var.aws_region
}

resource "aws_security_group" "web_sg" {
  name        = "web-sg"
  description = "Web Server SG allow SSH & HTTP Ports"


  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # For testing; restrict to your IP for production.
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
    description = "Allow all out bound ports to all destinations"
  }
}

# EC2 Instance
resource "aws_instance" "web_server" {
  ami           = var.aws_ami
  instance_type = var.instance_type
  key_name      = "desktop"

  security_groups = [ aws_security_group.web_sg.name ]

  tags = {
    "Name"      = "Web_Server"
    "ManagedBy" = "IaC"
  }


  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      host        = self.public_ip
      private_key = file("./desktop.pem")
    }

    inline = [
      "set -x",                            # Enable debugging for executed commands
      "sudo apt-get update -y",            # Update package repositories
      "sudo apt-get install -y nginx",     # Install Nginx
      "sudo systemctl start nginx",        # Start Nginx service
      "sudo systemctl enable nginx",       # Enable Nginx to start on boot
      "sudo systemctl status nginx || true" # Log Nginx status and continue even if non-zero
    ]
    
  }

}
*/

provider "aws" {
  region = "ap-south-1" # Change to your preferred region
}

# Create a secret in AWS Secrets Manager
resource "aws_secretsmanager_secret" "db_password" {
  name        = "db_password"
  description = "Database password for the EC2 instance"
}

resource "aws_secretsmanager_secret_version" "db_password_version" {
  secret_id = aws_secretsmanager_secret.db_password.id
  secret_string = jsonencode({
    password = "MySecurePassword123!" # Replace with your password
  })
}

# Retrieve the secret using the data source
data "aws_secretsmanager_secret" "db_password" {
  name = aws_secretsmanager_secret.db_password.name
}

data "aws_secretsmanager_secret_version" "db_password_version" {
  secret_id = data.aws_secretsmanager_secret.db_password.id
}

# Output the secret value
output "db_password" {
  value       = jsondecode(data.aws_secretsmanager_secret_version.db_password_version.secret_string).password
  sensitive   = true
}

# Security Group for the EC2 instance
resource "aws_security_group" "allow_ssh" {
  name_prefix = "allow_ssh"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Replace with a more secure CIDR range
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 Instance
resource "aws_instance" "web_server" {
  ami           = "ami-123456" # Replace with your AMI ID
  instance_type = "t2.micro"
  key_name      = "desktop" # Replace with the name of your key pair in AWS
  security_groups = [aws_security_group.allow_ssh.name]

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("./desktop.pem") # Reference your `desktop.pem` key
      host        = self.public_ip
    }

    inline = [
      "echo 'Database password: $(aws secretsmanager get-secret-value --secret-id ${aws_secretsmanager_secret.db_password.name} --query SecretString --output text)' > /home/ec2-user/db_password.txt"
    ]
  }

  tags = {
    Name = "web-server-with-secret"
  }
}
