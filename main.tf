#####################################################################
provider "aws" {
  access_key = var.access_key
  secret_key = var.secret_key
  region = "us-east-1"
}
######################### VPC #########################################
resource "aws_vpc" "d5-1_vpc" {
  cidr_block       = "10.0.0.0/16"
  tags = {
    Name = "d5-1_vpc"
  }
}
####################### SUBNET ##########################################
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

#################### SECURITY_GROUP #######################################
resource "aws_security_group" "agent_manager_sg" {
  name ="agent_manager_sg"
  description = "agent_manager_sg"
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

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}


resource "aws_security_group" "agent_sg" {
  name ="agent_sg"
  description = "agent_sg"
  vpc_id = aws_vpc.d5-1_vpc.id
  
  ingress {
    from_port = 22
    to_port = 22
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

resource "aws_security_group" "load_balancer_sg" {
  name        = "load-balancer-sg"
  description = "Security group for the load balancer"
  vpc_id      = aws_vpc.d5-1_vpc.id

# Since the application is accessed through 8000 
# The Load balancer needs to be able to accept traffic from that port 
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
 egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}
##################################### EC2 #################################################
resource "aws_instance" "jenkins_ec2" {
  ami           = "ami-053b0d53c279acc90"
  instance_type = "t2.medium"
  availability_zone = "us-east-1a" # Specify the desired availability zone
  subnet_id = aws_subnet.public_1.id
  vpc_security_group_ids = [aws_security_group.agent_manager_sg.id]
  key_name = "deploy_6"
  user_data = "${file("jenkins_install.sh")}"
  tags = {
    Name = "jenkins_ec2"
  }

}

resource "aws_instance" "app_ec2_1" {
  ami           = "ami-053b0d53c279acc90"
  instance_type = "t2.medium"
  availability_zone = "us-east-1a" # Specify the desired availability zone
  subnet_id = aws_subnet.public_1.id
  vpc_security_group_ids = [aws_security_group.agent_sg.id]
  key_name = "deploy_6"
  user_data = "${file("jenkins_install.sh")}"
  tags = {
    Name = "App_ec2_1"
  }
}

resource "aws_instance" "app_ec2_2" {
  ami           = "ami-053b0d53c279acc90"
  instance_type = "t2.medium"
  availability_zone = "us-east-1b" # Specify the desired availability zone
  subnet_id = aws_subnet.public_2.id
  vpc_security_group_ids = [aws_security_group.agent_sg.id]
  key_name = "deploy_6"
  user_data = "${file("jenkins_install.sh")}"
  tags = {
    Name = "App_ec2_2"
  }
}
####################### IGW ##################################################################
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.d5-1_vpc.id

  tags = {
    Name = "gw_d5"
  }
}

########################### ROUTE TABLE ######################################################
resource "aws_default_route_table" "route5_1" {
  default_route_table_id = aws_vpc.d5-1_vpc.default_route_table_id
   route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

######################### TARGET GROUP CREATION ######################################
## Create a target group for the load balancer to use
## port 8000 is used for our application 
resource "aws_lb_target_group" "app_backups_ec2" {
  name = "AppBackupsEC2"
  port = 8000
  protocol = "HTTP"
  vpc_id = aws_vpc.d5-1_vpc.id
}
#################### EC2 ATTACHMENT TO TARGET GROUP ###########################################
## Once the target group resource has been created
## attach each agent ec2 -> target group
#AmazonResourceName
resource "aws_lb_target_group_attachment" "register_target_1" {
  target_group_arn = aws_lb_target_group.app_backups_ec2.arn
  target_id = aws_instance.app_ec2_1.id
  port = 8000
}

resource "aws_lb_target_group_attachment" "register_target_2" {
  target_group_arn = aws_lb_target_group.app_backups_ec2.arn
  target_id = aws_instance.app_ec2_2.id
  port = 8000
}


###################### LOADBALANCER  ###################################################
resource "aws_lb" "my_load_balancer" {
  name               = "my-load-balancer"
  internal           = false # Set to true for internal ALB
  load_balancer_type = "application"
  security_groups    = [aws_security_group.load_balancer_sg.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]
}


############################# LISTNER ###########################################
#Each load balancer needs a listener to accept incoming requests
resource "aws_lb_listener" "traffichandler" {
  load_balancer_arn = aws_lb.my_load_balancer.arn
  port              = "80"
  protocol          = "HTTP"
 default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_backups_ec2.arn
  }
}

