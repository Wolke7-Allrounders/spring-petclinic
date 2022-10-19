#resource "aws_ecr_repository" "worker" {
 #   name  = "worker"
#}

resource "aws_ecs_cluster" "test-cluster" {
  name = "myapp-cluster"
  #capacity_providers =["EC2"]
}

data "template_file" "testapp" {
  template = file("./templates/image/image.json")

  vars = {
    app_image      = var.app_image
    app_port       = var.app_port
    fargate_cpu    = var.fargate_cpu
    fargate_memory = var.fargate_memory
    aws_region     = var.aws_region
  }
}

resource "aws_ecs_task_definition" "test-def" {
  family                   = "testapp-task"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  #network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  cpu                      = var.fargate_cpu
  memory                   = var.fargate_memory
  container_definitions    = data.template_file.testapp.rendered
  task_role_arn            = aws_iam_role.ecs_task_execution_role.arn
}

resource "aws_ecs_service" "test-service" {
  name            = "testapp-service"
  cluster         = "${aws_ecs_cluster.test-cluster.id}"
  task_definition = "${aws_ecs_task_definition.test-def.arn}"
  desired_count   = 1
  launch_type     = "EC2"
 

  load_balancer {
    target_group_arn = aws_alb_target_group.myapp-tg.arn
    container_name   = "testapp"
    container_port   = 8080
  }

   #network_configuration {   
   # subnets               = aws_subnet.private.*.id  ## Enter the private subnet id
   # assign_public_ip      = "false"
 # }

  depends_on = [aws_alb_listener.testapp, aws_iam_role_policy_attachment.ecs_task_execution_role]
}

