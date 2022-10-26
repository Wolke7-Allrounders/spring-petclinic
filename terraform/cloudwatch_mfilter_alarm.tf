#cloudwatch_mfilter_alarm


#resource "aws_sns_topic" "wolke7_teams_topic" {
#  name = "wolke7_teams_topic"
#}


# https://spin.atomicobject.com/2021/04/07/aws-cloudwatch-metric-filter-alarm-terraform/

resource "aws_cloudwatch_log_metric_filter" "wolke7-metricfilter" {
  name           = "wolke7-metricfilter"
  log_group_name = "/wolke7-ecs-demo/petclinic"
  pattern        = "RuntimeException"
  metric_transformation {
    name      = "RuntimeExceptionMetric"
    namespace = "ImportantMetrics"
    value     = "1"
  }
}



# https://registry.terraform.io/modules/aloukiala/alarm-chat-notification/aws/latest


module "alarm-chat-notification" {
  source  = "aloukiala/alarm-chat-notification/aws"
  version = "0.1.0"
  # insert the 1 required variable here
  teams_webhook_url = "https://muss_hier_noch_eingesetzt_werden_in_git_gibt_es_wieder_stress"
}

#module "teams_hook" {
#    # source = "terraform-aws-alarm-chat-notification/"
#    source = "alarm-chat-notification"
#    teams_webhook_url = ""
#}

#resource "aws_cloudwatch_metric_alarm" "api_gtw_latency_alarm" {
#    alarm_name          = "api_gtw_latency_alarm"
#    comparison_operator = "GreaterThanOrEqualToThreshold"
#    evaluation_periods  = "5"
#    metric_name         = "Latency"
#    namespace           = "AWS/ApiGateway"
#    period              = "300"
#    statistic           = "Maximum"
#    threshold           = "10000"
#
#    dimensions = {
#      ApiName     = aws_api_gateway_rest_api.ApiGateway.name
#    }
#
#    alarm_description = "API GTW latency alarm on maximum crossing limit"
#    alarm_actions = [module.teams_hook.alarm_sns_topic_arn]
#}

resource "aws_cloudwatch_metric_alarm" "wolke7-mf-RTException-alarm" {
  alarm_name = "wolke7-mf-RTException-alarm"
  metric_name         = aws_cloudwatch_log_metric_filter.wolke7-metricfilter.name
  threshold           = "1"
  statistic           = "Sum"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  datapoints_to_alarm = "1"
  evaluation_periods  = "5"
  period              = "60"
  namespace           = "ImportantMetrics"
  alarm_description = "RuntimeExceptionMetric Alarm"
#  alarm_actions = [module.teams_hook.alarm_sns_topic_arn]
  alarm_actions = [module.alarm-chat-notification.alarm_sns_topic_arn]
}



