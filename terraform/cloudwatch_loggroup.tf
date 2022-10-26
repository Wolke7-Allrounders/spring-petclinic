# cloudwatch_loggroup.tf

# Set up CloudWatch group and log stream and retain logs for 30 days


resource "aws_cloudwatch_log_group" "wolke7-ecs" {
  name = "/wolke7-ecs-demo/petclinic"
}
