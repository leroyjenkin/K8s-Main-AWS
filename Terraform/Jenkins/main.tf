provider "aws" {
  region = "eu-central-1" # Replace with your AWS region
}

# Data source to reference the existing subnet
data "aws_subnet" "existing_subnet" {
  id = "subnet-0ab6abacabc196fdc" # Replace with the actual ID of your existing subnet
}

# Create an EC2 Instance
resource "aws_instance" "jenkins_server" {
  ami           = "ami-00d72ec36cdfc8a0a" # Replace with the desired AMI ID
  instance_type = "t3.medium" # Choose an appropriate instance type
  associate_public_ip_address = true # Ensure the instance gets a public IP

  vpc_security_group_ids = [aws_security_group.jenkins_sg.id]
  key_name               = "jenkins" # Use the existing key pair

  user_data = <<-EOF
    #!/bin/bash
    exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
    set -x

    # Update the system
    yum update -y

    # Install Java OpenJDK 17
    amazon-linux-extras enable java-openjdk17
    yum install -y java-17*

    # Add Jenkins repository
    echo '[jenkins]
    name=Jenkins-stable
    baseurl=http://pkg.jenkins.io/redhat-stable
    gpgcheck=1
    gpgkey=http://pkg.jenkins.io/redhat-stable/jenkins.io.key' > /etc/yum.repos.d/jenkins.repo

    # Import Jenkins GPG key manually
    rpm --import http://pkg.jenkins.io/redhat-stable/jenkins.io.key

    # Install Jenkins
    yum install jenkins -y

    # Check Jenkins installation
    rpm -qa | grep jenkins

    # Start and enable Jenkins service
    systemctl start jenkins
    systemctl enable jenkins

    # Check Jenkins service status
    systemctl status jenkins

    # Install Docker
    yum install -y docker
    usermod -aG docker jenkins
    systemctl start docker
    systemctl enable docker

    # Install AWS CLI
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install

    # Install git
    yum install -y git
  EOF

  tags = {
    Name = "Jenkins Server"
  }

  # Use the existing subnet retrieved by the data source
  subnet_id = data.aws_subnet.existing_subnet.id
}

# Create a Security Group for Jenkins (replace with your security group rules)
resource "aws_security_group" "jenkins_sg" {
  name        = "jenkins_sg"
  description = "Security Group for Jenkins Server"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow SSH from anywhere (for testing, restrict in production)
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow Jenkins access from anywhere (for testing, restrict in production)
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # Allow all outbound traffic
  }
}

# Removed the aws_subnet resource block

# Output the public DNS of the EC2 instance
output "jenkins_server_public_dns" {
  value = aws_instance.jenkins_server.public_dns
  description = "Public DNS of the Jenkins Server"
}
