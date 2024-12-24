

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
