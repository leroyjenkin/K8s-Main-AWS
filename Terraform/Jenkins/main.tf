provider "aws" {
  region = "eu-central-1" # Keep the region as you specified
}

# Data source to fetch the existing EKS cluster
data "aws_eks_cluster" "eks" {
  name = "education-eks-uQvzGXPT" # Keep the EKS cluster name as you specified
}

# Data source to fetch the VPC configuration of the EKS cluster
data "aws_vpc" "eks_vpc" {
  id = data.aws_eks_cluster.eks.vpc_config[0].vpc_id
}

# Data source to fetch the subnets associated with the EKS cluster
data "aws_subnets" "eks_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.eks_vpc.id]
  }
}

resource "aws_security_group" "jenkins_sg" {
  vpc_id = data.aws_vpc.eks_vpc.id
  name_prefix = "jenkins-sg-"

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "jenkins_key" {
  key_name   = "jenkins-key"
  public_key = file("~/.ssh/id_rsa.pub")
}

resource "aws_instance" "jenkins" {
  ami           = "ami-00d72ec36cdfc8a0a" # Keep the AMI as you specified
  instance_type = "t3.medium" # Keep the instance type as you specified
  associate_public_ip_address = true # Ensure the instance gets a public IP


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
              EOF

  vpc_security_group_ids = [aws_security_group.jenkins_sg.id]

  key_name = aws_key_pair.jenkins_key.key_name

  # Using the first subnet from the EKS subnets
  subnet_id = data.aws_subnets.eks_subnets.ids[0]

  # Add tags to the instance
  tags = {
    Name = "jenkins-tf"
  }
}

output "jenkins_url" {
  value = aws_instance.jenkins.public_dns
}
