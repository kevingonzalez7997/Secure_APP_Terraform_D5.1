#####################################################################
provider "aws" {
  access_key = var.access_key
  secret_key = var.secret_key
  region = "us-east-1"
}
#########################V P C#########################################
resource "aws_vpc" "d5-1_vpc" {
  cidr_block       = "10.0.0.0/16"
  tags = {
    Name = "d5-1_vpc"
  }
}
#######################S U B N E T####################################
resource "aws_subnet" "public_1" {
    cidr_block = "10.0.1.0/24"
    vpc_id = aws_vpc.d5-1_vpc.id
    availability_zone = "us-east-1a"
    map_public_ip_on_launch = true  
}

resource "aws_subnet" "public_2" {
    cidr_block = "10.0.2.0/24"
    vpc_id = aws_vpc.d5-1_vpc.id
    availability_zone = "us-east-1b"
    map_public_ip_on_launch = true  
}

####################S E C U R I T Y  G R O U P###########################
resource "aws_security_group" "pub1_sercurity" {
  name ="pub1_sercurity"
  description = "pub1_sercurity"
  vpc_id = aws_vpc.d5-1_vpc.id
  
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 8000
    to_port = 8000
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}
##################################I N S T A N C E S#################################################
resource "aws_instance" "jenkins_ec2" {
  ami           = "ami-053b0d53c279acc90"
  instance_type = "t2.medium"
  availability_zone = "us-east-1b" # Specify the desired availability zone
  subnet_id = aws_subnet.public_2.id
  vpc_security_group_ids = [aws_security_group.pub1_sercurity.id]
  key_name = "Deployment_5_1"
  user_data = "${file("jenkins_install.sh")}"
  tags = {
    Name = "jenkins_ec2"
  }

}

resource "aws_instance" "app_ec2_1" {
  ami           = "ami-053b0d53c279acc90"
  instance_type = "t2.medium"
  availability_zone = "us-east-1b" # Specify the desired availability zone
  subnet_id = aws_subnet.public_2.id
  vpc_security_group_ids = [aws_security_group.pub1_sercurity.id]
  key_name = "Deployment_5_1"
  tags = {
    Name = "App_ec2_1"
  }
}

resource "aws_instance" "app_ec2_2" {
  ami           = "ami-053b0d53c279acc90"
  instance_type = "t2.medium"
  availability_zone = "us-east-1a" # Specify the desired availability zone
  subnet_id = aws_subnet.public_1.id
  vpc_security_group_ids = [aws_security_group.pub1_sercurity.id]
  key_name = "Deployment_5_1"
  tags = {
    Name = "App_ec2_2"
  }
}
#######################I G W#################################################################
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.d5-1_vpc.id

  tags = {
    Name = "gw_d5"
  }
}

###########################R O U T E  T A B L E###############################################
resource "aws_default_route_table" "route5_1" {
  default_route_table_id = aws_vpc.d5-1_vpc.default_route_table_id
   route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}
