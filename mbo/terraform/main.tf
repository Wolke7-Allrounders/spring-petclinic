terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.1.0"
    }
  }

    backend "s3" {
        bucket = "wolke7-terraform-s3"
        key    = "state.tfstate"
    }

}


# Configure the AWS Provider
provider "aws" {
}

# https://learn.hashicorp.com/tutorials/terraform/data-sources
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

 filter {
    name   = "name"
    values = ["amzn-ami*amazon-ecs-optimized"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}


resource "aws_vpc" "wolke7-ecs-vpc" {
    cidr_block = "10.0.0.0/20"
    enable_dns_support   = true
    enable_dns_hostnames = true
    tags       = {
        Name = "Wolke7-ECS-VPC"
    }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.wolke7-ecs-vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "eu-central-1c"

  tags = {
            Name        = "Wolke7-ECS-PRIVSUBNET"
            Environment = "Wolke7-ECS"
  }
}

resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.wolke7-ecs-vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-central-1c"
  map_public_ip_on_launch = true

  tags = {
            Name        = "Wolke7-ECS-PUBSUBNET"
            Environment = "Wolke7-ECS"
  }
}


resource "aws_internet_gateway" "wolke7-ecs-aws-igw" {
        vpc_id = aws_vpc.wolke7-ecs-vpc.id
        tags = {
                Name        = "Wolke7-ECS-IGW"
                Environment = "Wolke7-ECS"
  }
}

resource "aws_route_table" "public" {
    vpc_id = aws_vpc.wolke7-ecs-vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.wolke7-ecs-aws-igw.id
    }
}

resource "aws_route_table_association" "route_table_association" {
    subnet_id      = aws_subnet.public.id
    route_table_id = aws_route_table.public.id
}


# First security group is for the EC2 that will live in ECS cluster. Inbound traffic is narrowed to two ports: 22 for SSH and 443 for HTTPS needed to download the docker image from ECR.
resource "aws_security_group" "wolke7-ecs-sg" {
    vpc_id      = aws_vpc.wolke7-ecs-vpc.id

    ingress {
        from_port       = 22
        to_port         = 22
        protocol        = "tcp"
        cidr_blocks     = ["0.0.0.0/0"]
    }

    ingress {
        from_port       = 443
        to_port         = 443
        protocol        = "tcp"
        cidr_blocks     = ["0.0.0.0/0"]
    }

    ingress {
        from_port       = 80
        to_port         = 80
        protocol        = "tcp"
        cidr_blocks     = ["0.0.0.0/0"]
    }

    egress {
        from_port       = 0
        to_port         = 65535
        protocol        = "tcp"
        cidr_blocks     = ["0.0.0.0/0"]
    }
}

resource "aws_launch_configuration" "wolke7_ecs_launch_config" {
    image_id             = data.aws_ami.amazon_linux_2.id
    iam_instance_profile = "ecs_agent_instance_profile"
    security_groups      = [aws_security_group.wolke7-ecs-sg.id]
    user_data            = "#!/bin/bash\necho ECS_CLUSTER=wolke7-ecs-cluster >> /etc/ecs/ecs.config"
    instance_type        = "t2.small"
	  key_name             = "mbo_key_pair"
}

resource "aws_autoscaling_group" "wolke7_ecs_asg" {
    name                      = "wolke7_ecs_asg"
    vpc_zone_identifier       = [aws_subnet.public.id]
    launch_configuration      = aws_launch_configuration.wolke7_ecs_launch_config.name

    desired_capacity          = 2
    min_size                  = 1
    max_size                  = 10
    health_check_grace_period = 300
    health_check_type         = "EC2"
}


# ECS

resource "aws_ecs_cluster" "wolke7-ecs-cluster" {
    name  = "wolke7-ecs-cluster"
}

data "aws_iam_policy_document" "ecs_agent_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecs_agent_policy" {
  role       = aws_iam_role.ecs_agent.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceRole"
}

resource "aws_iam_role" "ecs_agent" {
  name               = "ecs_agent"
  assume_role_policy = data.aws_iam_policy_document.ecs_agent_policy.json
}


resource "aws_iam_instance_profile" "ecs_agent_instance_profile" {
  name = "ecs_agent_instance_profile"
  role = aws_iam_role.ecs_agent.name
}






