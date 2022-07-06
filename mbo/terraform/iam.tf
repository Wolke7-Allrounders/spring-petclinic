data "aws_iam_policy_document" "ecs_agent_policy_1" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "ecs_agent_policy_2" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_agent_" {
  name               = "ecs_agent"
  assume_role_policy = data.aws_iam_policy_document.ecs_agent.json
}



resource "aws_iam_role_policy_attachment" "ecs_agent_policy_1" {
  #role       = "aws_iam_role.ecs_agent.name"
  role       = "aws_iam_role.ecs_agent"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
  }

resource "aws_iam_role_policy_attachment" "ecs_agent_policy_2" {
  #role       = "aws_iam_role.ecs_agent.name"
  role       = "aws_iam_role.ecs_agent"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceRole"
}

resource "aws_iam_instance_profile" "ecs_agent_instance_profile" {
  name = "ecs_agent"
  #role = aws_iam_role.ecs_agent.name
  role = "aws_iam_role.ecs_agent"
}
