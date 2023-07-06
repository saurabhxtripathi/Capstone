provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "example" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "example-vpc"
  }
}

resource "aws_subnet" "public1" {
  vpc_id = aws_vpc.example.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "public-subnet-1"
  }
}

resource "aws_subnet" "public2" {
  vpc_id = aws_vpc.example.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  tags = {
    Name = "public-subnet-2"
  }
}

resource "aws_instance" "ec2_instance" {
  ami = "ami-007855ac798b5175e"
  instance_type = "t2.medium"
  count = 3
  subnet_id = aws_subnet.public1.id
  vpc_security_group_ids = [aws_security_group.instance.id]
  associate_public_ip_address = true  
  tags = {
    Name = "kube_nodes-${count.index}"
  }
}

resource "aws_security_group" "instance" {
  name_prefix = "instance-sg"
  vpc_id = aws_vpc.example.id

  ingress {
    from_port = 0
    to_port = 65535
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 65535
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "ingress-all" {
  type        = "ingress"
  from_port   = 0
  to_port     = 0
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]   # Allow all traffic from anywhere

  security_group_id = aws_security_group.instance.id
}


resource "aws_eip" "example" {
  vpc = true
}

resource "aws_security_group" "alb" {
  name_prefix = "alb-sg"
  vpc_id = aws_vpc.example.id

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "example" {
  name = "example-alb"
  internal = false
  load_balancer_type = "application"
  subnets = [aws_subnet.public1.id, aws_subnet.public2.id]
  security_groups = [aws_security_group.alb.id]
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.example.arn
  port = 80
  protocol = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.http.arn
    type = "forward"
  }
}

resource "aws_lb_target_group" "http" {
  name = "http-target-group"
  port = 80
  protocol = "HTTP"
  vpc_id = aws_vpc.example.id
}

resource "aws_lb_target_group_attachment" "http" {
  target_group_arn = aws_lb_target_group.http.arn
  count = 3
  target_id = aws_instance.ec2_instance[count.index].id
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.example.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.example.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "example-public"
  }
}

resource "aws_route_table_association" "public1" {
  subnet_id      = aws_subnet.public1.id
  route_table_id = aws_route_table.public.id
}
