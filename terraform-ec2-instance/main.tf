# Configure the AWS Provider
//Define the provider
provider "aws" {
  region = "ap-southeast-2"
}

// Define the variables
variable vpc_cidr_block {}
variable subnet_cidr_block {}
variable availability_zone {}
variable env_profix {}
variable my_ip_address {}
variable instance_type {}
variable public_key_location { }
variable ssh_private_key_location {
  
}
variable server_user {}
variable instance_number {
  
}

// 1) Create a vpc 
resource "aws_vpc" "myapp_vpc" {
  cidr_block = var.vpc_cidr_block
  enable_dns_hostnames = true
  tags = {
    Name = "${var.env_profix}-vpc"
  }
}

// 2) Create a subnet for that created vpc
resource "aws_subnet" "myapp_subnet-1" {
  vpc_id = aws_vpc.myapp_vpc.id
  cidr_block = var.subnet_cidr_block
  availability_zone = var.availability_zone
  tags = {
    Name: "${var.env_profix}-subnet-1"
  }
}

// 3) Create a internet gateway for that created vpc

resource "aws_internet_gateway" "myapp_igw" {
  vpc_id = aws_vpc.myapp_vpc.id
  tags = {
    Name = "${var.env_profix}-igw"
  }
}

// 4-1) Create a new route table for external request traffic be access to that created vpc
# resource "aws_route_table" "myapp_route_table" {
#   vpc_id = aws_vpc.myapp_vpc.id
#   route {
#     cidr_block = "0.0.0.0/0"
#     gateway_id = aws_internet_gateway.myapp_igw.id
#   }
#   tags = {
#     Name : "${var.env_profix}-route-table"
#   }
  
# }

// 4-2) Update the main/default route table for external request traffic be access to that created vpc instead
// of create a new one
resource "aws_default_route_table" "main_route_table" {
  default_route_table_id = aws_vpc.myapp_vpc.default_route_table_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.myapp_igw.id
  }
  tags = {
    Name = "${var.env_profix}-main-route-table"
  }
  
}

// 5) Accociate subnet with the new route table
# resource "aws_route_table_association" "association_rtb_subnet" {
#   subnet_id = aws_subnet.myapp_subnet-1.id
#   route_table_id = aws_route_table.myapp_route_table.id 
# }

// 6) Create security group based on default security group
resource "aws_default_security_group" "myapp_default_security_group" {
  vpc_id = aws_vpc.myapp_vpc.id
  
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = [ var.my_ip_address]
  }
  ingress {
    from_port = 8080
    to_port = 8080  
    protocol = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    prefix_list_ids = []
  }

  tags ={
    Name = "${var.env_profix}-myapp_new_security_group"
  }
}

// 7) Create ec2 instance inside that created vpc

data "aws_ami" "latest-amazon-linux-image" {
  most_recent = true
  owners = ["amazon"]
  filter {
    name = "name"
    values = [ "amzn2-ami-kernel-5.10-hvm-*-x86_64-gp2" ]
  }
  filter {
    name = "virtualization-type"
    values = [ "hvm" ]
  }
}

output "aws_ami_id" {
  value = data.aws_ami.latest-amazon-linux-image.id
}

resource "aws_key_pair" "ssh-key" {
  key_name = "server-key"
  public_key = file(var.public_key_location)
  
}

resource "aws_instance" "myapp_server" {
  ami =data.aws_ami.latest-amazon-linux-image.id

  count=var.instance_number

  instance_type = var.instance_type

  subnet_id = aws_subnet.myapp_subnet-1.id
  vpc_security_group_ids = [aws_default_security_group.myapp_default_security_group.id]
  availability_zone = var.availability_zone

  associate_public_ip_address = true
  key_name = aws_key_pair.ssh-key.key_name

  tags = {
     Name = "${var.env_profix}-server-${count.index+1}"
  }

  # provisioner "local-exec" {

  #   working_dir = "../ansible"
  #   command = "ansible-playbook -i '${self.public_ip},' --private-key ${var.ssh_private_key_location} -u ${var.server_user} docker_deploy_app.yaml"
    
  # }

  
}

output "ec2_public_ip" {
  value = aws_instance.myapp_server.*.public_ip
}
