provider "aws" {
  region = "eu-central-1"
}

# Security Group for SonarQube
resource "aws_security_group" "sonarqube_sg" {
  name        = "sonarqube-sg"
  description = "Security group for SonarQube EC2 instance"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow SSH access from anywhere
  }

  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow HTTP access for SonarQube
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # Allow all outbound traffic
  }
}

# EC2 instance for SonarQube
resource "aws_instance" "sonarqube_ec2" {
  ami           = "ami-00d72ec36cdfc8a0a" # Same AMI as Maven
  instance_type = "t2.medium" # Recommended minimum for SonarQube
  subnet_id     = "subnet-0ab6abacabc196fdc" # Same subnet as Maven

  tags = {
    Name = "sonarqube-instance"
  }

  user_data = <<-EOT
              #!/bin/bash
              # Update the system and install Java 17
              yum update -y
              amazon-linux-extras enable corretto11
              yum install -y java-17-amazon-corretto

              # Set SONAR_JAVA_PATH to the Java executable
              echo "export SONAR_JAVA_PATH=$(readlink -f $(which java))" >> /etc/profile
              source /etc/profile

              # Download and configure SonarQube
              curl -O https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-9.9.0.65466.zip
              yum install -y unzip
              unzip sonarqube-9.9.0.65466.zip
              mv sonarqube-9.9.0.65466 /opt/sonarqube
              useradd sonar
              chown -R sonar:sonar /opt/sonarqube
              chmod -R 755 /opt/sonarqube

              # Configure SonarQube systemd service
              echo "[Unit]
              Description=SonarQube service
              After=network.target
              [Service]
              User=sonar
              Group=sonar
              Type=simple
              ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
              User=sonar
              Environment=SONAR_JAVA_PATH=$(readlink -f $(which java))
              Restart=always
              [Install]
              WantedBy=multi-user.target" > /etc/systemd/system/sonarqube.service

              # Start and enable SonarQube
              systemctl daemon-reload
              systemctl start sonarqube
              systemctl enable sonarqube
              EOT

  key_name = "jenkins" # Replace with your key pair name

  # Use vpc_security_group_ids for VPC-based EC2 instances
  vpc_security_group_ids = [aws_security_group.sonarqube_sg.id]
}

# Output the public DNS of the SonarQube instance
output "sonarqube_instance_public_dns" {
  value       = aws_instance.sonarqube_ec2.public_dns
  description = "The public DNS of the SonarQube EC2 instance"
}
