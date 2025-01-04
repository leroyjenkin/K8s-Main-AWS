provider "aws" {
  region = "eu-central-1"
}

resource "aws_security_group" "maven_sg" {
  name        = "maven-sg"
  description = "Security group for Maven EC2 instance"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow SSH access from anywhere
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow HTTP access from anywhere
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # Allow all outbound traffic
  }
}

resource "aws_instance" "maven_ec2" {
  ami           = "ami-00d72ec36cdfc8a0a" # Replace with a valid Amazon Linux 2 AMI ID in eu-central-1
  instance_type = "t2.micro"
  subnet_id     = "subnet-0ab6abacabc196fdc"

  tags = {
    Name = "maven-instance"
  }

  user_data = <<-EOT
              #!/bin/bash
              yum update -y
              yum install -y java-1.8.0-openjdk-devel
              curl -O https://archive.apache.org/dist/maven/maven-3/3.8.5/binaries/apache-maven-3.8.5-bin.tar.gz
              tar xvf apache-maven-3.8.5-bin.tar.gz
              mv apache-maven-3.8.5 /usr/local/apache-maven
              echo "export PATH=/usr/local/apache-maven/bin:$PATH" >> /etc/profile
              source /etc/profile
              EOT

  key_name = "jenkins" # Replace with your key pair name

  # Use vpc_security_group_ids for VPC-based EC2 instances
  vpc_security_group_ids = [aws_security_group.maven_sg.id]
}

output "maven_instance_public_dns" {
  value = aws_instance.maven_ec2.public_dns
  description = "The public DNS of the Maven EC2 instance"
}
