# 1. Define Auto Scaling Target for ECS Service
resource "aws_appautoscaling_target" "ecs_scaling_target" {
  max_capacity       = 5  # Adjust as needed
  min_capacity       = 1  # Minimum number of tasks
  resource_id        = "service/${aws_ecs_cluster.shiny_cluster.name}/${aws_ecs_service.shiny_fargate_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# 2 Define CloudWatch Alarms and Policies for Scaling Out and Scaling In

# 2a.i CloudWatch Alarm for Scaling Out (Adding Capacity)
resource "aws_cloudwatch_metric_alarm" "sessions_per_task_scale_out_alarm" {
  alarm_name          = "${var.env}-sessions-per-task-scale-out-alarm"
  comparison_operator = "GreaterThanThreshold"         # Trigger when SessionsPerTask exceeds the threshold
  evaluation_periods  = 1                              # Evaluate over one period before taking action
  threshold           = 15                             # Threshold for scaling out (e.g., high traffic)
  metric_name         = "SessionsPerTask"              # Metric being monitored
  namespace           = "ShinyApp"                    # Custom namespace for Shiny app metrics
  statistic           = "Average"                     # Use the average value for evaluation
  period              = 30                             # Evaluate the metric every 30 seconds
  dimensions = {                                       # Dimension to identify the application
    Application = "ShinyApp"
  }
  alarm_description   = "Triggers a scale-out action when SessionsPerTask exceeds 15"
  treat_missing_data  = "ignore"                # Don't rely on gaps in data

  alarm_actions = [                                   # Action to take when the alarm triggers
    aws_appautoscaling_policy.scale_out_policy.arn
  ]
}

# 2a.ii Scaling Out Policy (Step Scaling for Adding Capacity)
resource "aws_appautoscaling_policy" "scale_out_policy" {
  name               = "sessions-per-task-scale-out-policy"
  resource_id        = aws_appautoscaling_target.ecs_scaling_target.id
  policy_type        = "StepScaling"                 # Policy type: StepScaling for fine-grained control
  service_namespace  = "ecs"                         # ECS service namespace
  scalable_dimension = "ecs:service:DesiredCount"    # The number of tasks to scale

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"     # Add or remove tasks as per step adjustments
    cooldown                = 120                   # Wait 120 seconds before another scaling action
    metric_aggregation_type = "Average"             # Use the average value for evaluation

    # Add one task when SessionsPerTask exceeds 15
    step_adjustment {
      metric_interval_lower_bound = 0              # Trigger when metric is greater than or equal to threshold
      scaling_adjustment          = 1               # Add one task
    }
  }
}

# 2b.i CloudWatch Alarm for Scaling In (Reducing Capacity)
resource "aws_cloudwatch_metric_alarm" "sessions_per_task_scale_in_alarm" {
  alarm_name          = "${var.env}-sessions-per-task-scale-in-alarm"
  comparison_operator = "LessThanThreshold"          # Trigger when SessionsPerTask drops below the threshold
  evaluation_periods  = 1                             # Evaluate over one period before taking action
  threshold           = 3                             # Threshold for scaling in (e.g., low traffic)
  metric_name         = "SessionsPerTask"             # Metric being monitored
  namespace           = "ShinyApp"                   # Custom namespace for Shiny app metrics
  statistic           = "Average"                    # Use the average value for evaluation
  period              = 30                            # Evaluate the metric every 30 seconds
  dimensions = {                                      # Dimension to identify the application
    Application = "ShinyApp"
  }
  alarm_description   = "Triggers a scale-in action when SessionsPerTask drops below 3 and tasks > 1"
  treat_missing_data  = "ignore"               # Don't rely on gaps in data

  alarm_actions = [                                  # Action to take when the alarm triggers
    aws_appautoscaling_policy.scale_in_policy.arn
  ]
}

# 2b.ii Scaling In Policy (Step Scaling for Reducing Capacity)
resource "aws_appautoscaling_policy" "scale_in_policy" {
  name               = "sessions-per-task-scale-in-policy"
  resource_id        = aws_appautoscaling_target.ecs_scaling_target.id
  policy_type        = "StepScaling"                 # Policy type: StepScaling for fine-grained control
  service_namespace  = "ecs"                         # ECS service namespace
  scalable_dimension = "ecs:service:DesiredCount"    # The number of tasks to scale

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"     # Add or remove tasks as per step adjustments
    cooldown                = 120                   # Wait 120 seconds before another scaling action
    metric_aggregation_type = "Average"             # Use the average value for evaluation

    # Remove one task when SessionsPerTask drops below 3
    step_adjustment {
      metric_interval_upper_bound = 0               # Trigger when metric is greater than or equal to threshold
      scaling_adjustment          = -1              # Remove one task
    }
  }
}

# 3. Define Alarms for Memory Utilization (without action), CPU Usage (without action)
# Just to track for testing purposes

# 3a. Memory Utilization Alarm -- Without Action
resource "aws_cloudwatch_metric_alarm" "memory_utilization_alarm" {
  alarm_name          = "${var.env}-memory-utilization-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 60                               # 1-minute aggregation
  statistic           = "Average"
  threshold           = 75.0                             # Adjust based on acceptable memory usage threshold
  
  dimensions = {
    ClusterName = aws_ecs_cluster.shiny_cluster.name
    ServiceName = aws_ecs_service.shiny_fargate_service.name
  }
}

# 3b. CPU Utilization Alarm -- Without Action
resource "aws_cloudwatch_metric_alarm" "cpu_utilization_alarm" {
  alarm_name          = "${var.env}-cpu-utilization-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60                               # 1-minute aggregation
  statistic           = "Average"
  threshold           = 75.0                             # Adjust based on acceptable CPU usage threshold
  
  dimensions = {
    ClusterName = aws_ecs_cluster.shiny_cluster.name
    ServiceName = aws_ecs_service.shiny_fargate_service.name
  }
}
