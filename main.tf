provider "aws" {
  region = "us-east-1" 
}

# Create a custom VPC
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "Terraform-VPC"
  }
}

# Create a public subnet in the VPC
resource "aws_subnet" "my_subnet" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.1.0/24"
  
  tags = {
    Name = "Terraform-Subnet"
  }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "Terraform-IGW"
  }
}

# Create a Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    # Route all outbound traffic to the Internet Gateway
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "Terraform-Public-Route-Table"
  }
}

# Associate the Route Table with the Subnet
resource "aws_route_table_association" "public_rt_assoc" {
  subnet_id      = aws_subnet.my_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# Define Security Group in the VPC
resource "aws_security_group" "allow_http" {
  vpc_id      = aws_vpc.my_vpc.id
  name        = "allow_http_traffic"
  description = "Allow HTTP inbound traffic"

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
    Name = "Terraform-SG"
  }
}

# Define EC2 Instance in the VPC
resource "aws_instance" "web" {
  ami           = "ami-0ebfd941bbafe70c6"  # Amazon Linux 2 AMI
  instance_type = "t2.micro"

  # Attach EC2 instance to the subnet and security group in the VPC
  subnet_id              = aws_subnet.my_subnet.id
  vpc_security_group_ids = [aws_security_group.allow_http.id]

  associate_public_ip_address = true

  tags = {
    Name = "Terraform-EC2"
  }

  user_data = <<-EOF
              #!/bin/bash
              # Update packages
              sudo yum update -y
              
              # Install Node.js and npm
              curl -sL https://rpm.nodesource.com/setup_14.x | sudo bash -
              sudo yum install -y nodejs

              # Create application directory
              mkdir /home/ec2-user/my-web-app
              cd /home/ec2-user/my-web-app

              # Create a simple Node.js app
              cat << 'EOT' > index.js
              const express = require('express');
              const app = express();
              const PORT = 3002;

              app.get('/', (req, res) => {
                  res.send('Hello from Terraform!');
              });

              app.listen(PORT, () => {
                  console.log('Server is running on http://localhost:' + PORT);
              });
              EOT

              # Install npm dependencies
              npm install express

              # Install PM2 to manage the app
              sudo npm install -g pm2
              pm2 start index.js --name my-web-app
              pm2 startup
              pm2 save
              EOF
}