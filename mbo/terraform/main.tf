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

# Die Resource "S3 Bucket" wurde vorher angelegt und per Console Versioning aktiviert
# daher NICHT hier auf diese Art:
# https://letslearndevops.com/2017/07/29/terraform-and-remote-state-with-s3/
# ACHTUNG: Bug, WA hier : https://github.com/mmatecki/tf-s3-state/tree/master/terraform
#
#resource "aws_s3_bucket" "tfstate" {
#bucket = "wolke7-terraform-s3"
#acl    = "private"
#
#  versioning {
#    enabled = true
#  }
#
#  lifecycle {
#    prevent_destroy = true
#  }
#}



# Configure the AWS Provider
provider "aws" {
}

#
# Networking
#

resource "aws_vpc" "wolke7-ecs-vpc" {
    cidr_block = "10.0.0.0/20"
    enable_dns_support   = true
    enable_dns_hostnames = true
    tags       = {
        Name = "Wolke7-ECS-VPC"
    }
}

# https://aws.amazon.com/de/vpc/faqs/
# F: Kann sich ein Subnetz über mehrere Availability Zones erstrecken?
# Nein. Ein Subnetz muss sich innerhalb einer einzigen Availability Zone befinden.
#
# OCI - geht

# Create Public Subnet1
resource "aws_subnet" "pub-sub1" {  
vpc_id                  = aws_vpc.wolke7-ecs-vpc.id  
cidr_block              = "10.0.2.0/24"
availability_zone       = "eu-central-1c"
map_public_ip_on_launch = true  
tags = {
            Name        = "Wolke7-ECS-PUB-SUBNET-1"
            Environment = "Wolke7-ECS"
      }
}

# Create Public Subnet2 
resource "aws_subnet" "pub-sub2" {  
vpc_id                  = aws_vpc.wolke7-ecs-vpc.id 
cidr_block              = "10.0.4.0/24"
availability_zone       = "eu-central-1b" 
map_public_ip_on_launch = true  
tags = {
            Name        = "Wolke7-ECS-PUB-SUBNET-2"
            Environment = "Wolke7-ECS"
       }
}


# Create Private Subnet1
resource "aws_subnet" "prv-sub1" {
  vpc_id                  = aws_vpc.wolke7-ecs-vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-central-1c"
  map_public_ip_on_launch = false
  tags = {
            Name        = "Wolke7-ECS-PRIV-SUBNET-1"
            Environment = "Wolke7-ECS" 
 }
}

# Create Private Subnet2
resource "aws_subnet" "prv-sub2" {
  vpc_id                  = aws_vpc.wolke7-ecs-vpc.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "eu-central-1b"
  map_public_ip_on_launch = false
  tags = {
            Name        = "Wolke7-ECS-PRIV-SUBNET-2"
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

resource "aws_route_table" "wolke7-ecs-route-table" {
    vpc_id = aws_vpc.wolke7-ecs-vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.wolke7-ecs-aws-igw.id
    }
}

resource "aws_route_table_association" "wolke7-ecs-rt1" {
    subnet_id = aws_subnet.pub-sub1.id
    route_table_id = aws_route_table.wolke7-ecs-route-table.id
}

resource "aws_route_table_association" "wolke7-ecs-rt2" {
    subnet_id = aws_subnet.pub-sub2.id
    route_table_id = aws_route_table.wolke7-ecs-route-table.id
}

#
# Load Balancer, Listener, Target Group
#

resource "aws_alb" "wolke7-ecs-alb" {
  name = "wolke7-ecs-alb"
  security_groups = [aws_security_group.wolke7-ecs-sg-alb.id] # hier will er unbedingt die Klammern !
  subnets = [aws_subnet.pub-sub1.id,aws_subnet.pub-sub2.id]
  enable_http2    = "true"
  idle_timeout    = 600
  }

output "wolke7-ecs-alb-output" {
  value = "${aws_alb.wolke7-ecs-alb.dns_name}"
}

resource "aws_alb_listener" "wolke7-ecs-alb-listener" {
  load_balancer_arn = aws_alb.wolke7-ecs-alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_alb_target_group.wolke7-ecs-target-group.arn
    type             = "forward"
  }
}

resource "aws_alb_target_group" "wolke7-ecs-target-group" {
  name       = "wolke7-ecs-target-group"
  port       = 80                                              # was ist mit Port Mapping ?
  protocol   = "HTTP"
  vpc_id     = "${aws_vpc.wolke7-ecs-vpc.id}"
  depends_on = [aws_alb.wolke7-ecs-alb]

  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400
  }

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 10
    timeout             = 60
    interval            = 300
    matcher             = "200,301,302"
  }
}


#
# Network Security
#

resource "aws_security_group" "wolke7-ecs-sg-ec2" {
  name = "wolke7-ecs-sg-ec2"
  description = "controls direct and through ALB Sec.-Group access to EC2 instances"

  ingress {
   from_port       = 22
   to_port         = 22
   protocol        = "tcp"
   cidr_blocks     = ["0.0.0.0/0"]
  }

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.wolke7-ecs-sg-alb.id]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.wolke7-ecs-sg-alb.id]
  }

  vpc_id = "${aws_vpc.wolke7-ecs-vpc.id}"
}

resource "aws_security_group" "wolke7-ecs-sg-alb" {
  name = "wolke7-ecs-sg-alb"
  description = "controls direct access to ALB"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id = "${aws_vpc.wolke7-ecs-vpc.id}"
}

# Both of these security groups allow ingress HTTP traffic on port 80 and all outbound traffic.
# However, the aws_security_group.wolke7-ecs-sg-ec2 security group restricts inbound traffic to requests coming from 
# any source associated with the aws_security_group.wolke7-ecs-sg-alb security group, 
# ensuring that only requests forwarded from your load balancer will reach your instances. 


#
# EC2
#

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

resource "aws_launch_configuration" "wolke7-ecs-launch-config" {
    image_id             = data.aws_ami.amazon_linux_2.id
    iam_instance_profile = aws_iam_instance_profile.wolke7-ecs-ec2-role-inst-profile.name
    security_groups      = [aws_security_group.wolke7-ecs-sg-ec2.id]
    user_data            = "#!/bin/bash\necho ECS_CLUSTER=wolke7-ecs-cluster >> /etc/ecs/ecs.config"
    instance_type        = "t2.small"
	  key_name             = "mbo_key_pair"
}

resource "aws_autoscaling_group" "wolke7-ecs-asg" {
    name                      = "wolke7-ecs-asg"
    vpc_zone_identifier       = [aws_subnet.pub-sub1.id,aws_subnet.pub-sub2.id]
    launch_configuration      = aws_launch_configuration.wolke7-ecs-launch-config.name
    desired_capacity          = 2
    min_size                  = 1
    max_size                  = 3
    health_check_grace_period = 300
    health_check_type         = "EC2"
    default_cooldown          = 300
    termination_policies      = ["OldestInstance"]
}

# This policy configures your Auto Scaling group to destroy a member of the ASG if the EC2 instances in your group 
# use less than 10% CPU over 2 consecutive evaluation periods of 2 minutes.
# This type of policy would allow you to optimize costs.
# https://learn.hashicorp.com/tutorials/terraform/aws-asg?utm_source=WEBSITE&utm_medium=WEB_IO&utm_offer=ARTICLE_PAGE&utm_content=DOCS&_ga=2.147521847.1849705710.1657203783-1477262622.1654253851

resource "aws_autoscaling_policy" "wolke7-ecs-scale-down" {
  name                   = "wolke7-ecs-scale-down"
  autoscaling_group_name = aws_autoscaling_group.wolke7-ecs-asg.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 300
}

resource "aws_cloudwatch_metric_alarm" "wolke7-ecs-scale-down" {
  alarm_description   = "Monitors CPU utilization for Wolke7 ECS ASG"
  alarm_actions       = [aws_autoscaling_policy.wolke7-ecs-scale-down.arn]
  alarm_name          = "wolke7-ecs-scale-down"
  comparison_operator = "LessThanOrEqualToThreshold"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  threshold           = "10"
  evaluation_periods  = "2"
  period              = "120"
  statistic           = "Average"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.wolke7-ecs-asg.name
  }
}

# Same for SCALE UP

resource "aws_autoscaling_policy" "wolke7-ecs-scale-up" {
  name                   = "wolke7-ecs-scale-up"
  autoscaling_group_name = aws_autoscaling_group.wolke7-ecs-asg.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1                      # NICHT +1, muss man nicht verstehen
  cooldown               = 300
}

resource "aws_cloudwatch_metric_alarm" "wolke7-ecs-scale-up" {
  alarm_description   = "Monitors CPU utilization for Wolke7 ECS ASG"
  alarm_actions       = [aws_autoscaling_policy.wolke7-ecs-scale-up.arn]
  alarm_name          = "wolke7-ecs-scale-up"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  threshold           = "50"
  evaluation_periods  = "2"
  period              = "120"
  statistic           = "Average"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.wolke7-ecs-asg.name
  }
}

# While you can use an aws_lb_target_group_attachment resource to directly associate an EC2 instance or 
# other target type with the target group, the dynamic nature of instances in an ASG makes that hard to maintain in configuration.
# Instead, this configuration links your Auto Scaling group with the target group using the aws_autoscaling_attachment resource.
# This allows AWS to automatically add and remove instances from the target group over their lifecycle. 

resource "aws_autoscaling_attachment" "wolke7-ecs-asa" {
  autoscaling_group_name = aws_autoscaling_group.wolke7-ecs-asg.id
  alb_target_group_arn   = aws_alb_target_group.wolke7-ecs-target-group.arn
}


#
# ECS, Task , Service
#

resource "aws_ecs_cluster" "wolke7-ecs-cluster" {
    name  = "wolke7-ecs-cluster"
}

# Wolke7 ECS Petclinic Service
resource "aws_ecs_service" "wolke7-ecs-petclinic-service" {
  name            = "wolke7-ecs-petclinic-service"
  cluster         = aws_ecs_cluster.wolke7-ecs-cluster.id
  task_definition = aws_ecs_task_definition.wolke7-ecs-petclinic-task-def.arn
  desired_count   = 2
  iam_role        = aws_iam_role.wolke7-ecs-service-role.arn
  depends_on      = [aws_iam_role_policy_attachment.wolke7-ecs-service-attach]
  launch_type     = "EC2"

  load_balancer {
    target_group_arn = aws_alb_target_group.wolke7-ecs-target-group.arn        # statt .id nun .arn
    container_name   = "petclinic"
    container_port   = "8080"      # doch 8080 , weil PortMapping , Port 80 bringt Fehler
  }

  network_configuration {
    subnets = [aws_subnet.pub-sub1.id,aws_subnet.pub-sub2.id]
    assign_public_ip = true
  }

  lifecycle {
    ignore_changes = [task_definition]
  }
}

resource "aws_ecs_task_definition" "wolke7-ecs-petclinic-task-def" {
  family = "petclinic"
  execution_role_arn = "arn:aws:iam::517204143657:role/ecsTaskExecutionRole" # nicht sicher, ob er das braucht

  container_definitions = <<EOF
[
  {
    "portMappings": [
      {
        "hostPort": 80,
        "protocol": "tcp",
        "containerPort": 8080
      }
    ],
    "cpu": 1024,
    "memory": 1024,
    "image": "517204143657.dkr.ecr.eu-central-1.amazonaws.com/wolke7-jki:latest",
    "essential": true,
    "name": "petclinic",
    "logConfiguration": {
    "logDriver": "awslogs",
      "options": {
        "awslogs-group": "/wolke7-ecs-demo/petclinic",
        "awslogs-region": "eu-central-1",
        "awslogs-stream-prefix": "wolke7-ecs"
      }
    }
  }
]
EOF

}

resource "aws_cloudwatch_log_group" "wolke7-ecs" {
  name = "/wolke7-ecs-demo/petclinic"
}


#
# IAM
#

# ECS EC2 Role
resource "aws_iam_role" "wolke7-ecs-ec2-role" {
  name = "wolke7-ecs-ec2-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "wolke7-ecs-ec2-role-inst-profile" {
  name = "wolke7-ecs-ec2-role-inst-profile"
  role = "${aws_iam_role.wolke7-ecs-ec2-role.name}"
}

resource "aws_iam_role_policy" "wolke7-ecs-ec2-role-policy" {
  name = "wolke7-ecs-ec2-role-policy"
  role = "${aws_iam_role.wolke7-ecs-ec2-role.name}"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
              "ecs:CreateCluster",
              "ecs:DeregisterContainerInstance",
              "ecs:DiscoverPollEndpoint",
              "ecs:Poll",
              "ecs:RegisterContainerInstance",
              "ecs:StartTelemetrySession",
              "ecs:Submit*",
              "ecs:StartTask",
              "ecr:GetAuthorizationToken",
              "ecr:BatchCheckLayerAvailability",
              "ecr:GetDownloadUrlForLayer",
              "ecr:BatchGetImage",
              "logs:CreateLogStream",
              "logs:PutLogEvents"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents",
                "logs:DescribeLogStreams"
            ],
            "Resource": [
                "arn:aws:logs:*:*:*"
            ]
        }
    ]
}
EOF
}

# ECS Service Role
resource "aws_iam_role" "wolke7-ecs-service-role" {
  name = "wolke7-ecs-service-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ecs.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "wolke7-ecs-service-attach" {
  role       = "${aws_iam_role.wolke7-ecs-service-role.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceRole"
}




