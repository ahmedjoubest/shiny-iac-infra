#' Update Active Sessions Metric Per Task
#'
#' Updates the active sessions count in DynamoDB, calculates sessions per task,
#' sends the updated value to CloudWatch for monitoring, and includes the task count.
#'
#' @param value Numeric. Increment (+1) or decrement (-1) to apply.
#' @param dynamodb_table_name Character. The name of the DynamoDB table.
#' @param cluster_name Character. The name of the ECS cluster.
#' @param service_name Character. The name of the ECS service.
#' @examples
#' update_active_sessions_per_task(1, "my-dynamodb-table", "my-cluster", "my-service")
update_active_sessions_per_task <- function(value, dynamodb_table_name, cluster_name, service_name) {
  
  # Initialize clients
  dynamodb <- paws::dynamodb()
  cloudwatch <- paws::cloudwatch()
  ecs <- paws::ecs()
  
  # Retrieve current global session value from DynamoDB
  current_value <- dynamodb$get_item(
    TableName = dynamodb_table_name,
    Key = list("MetricName" = list(S = "ActiveSessions"))
  )$Item$Value$N
  
  # Update the global session value
  if (is.null(current_value)) current_value <- 0
  current_value <- as.numeric(current_value) + value
  
  # Dynamically calculate task count
  tasks <- ecs$list_tasks(
    cluster = cluster_name,
    serviceName = service_name,
    desiredStatus = "RUNNING"
  )$taskArns
  
  task_count <- length(tasks)
  if (task_count <= 0) stop("No running tasks found for the specified service.")
  
  # Calculate sessions per task
  sessions_per_task <- current_value / task_count
  
  # Exception: if less than 3 sessions per task, and only 1 task, no need to trigger the alarm
  # Since we can't scale in below the minimum number of tasks (1 here)
  # --> We then set sessions per task to 3
  if (sessions_per_task < 3 && task_count == 1) {
    sessions_per_task <- 3
  }
  
  # Persist updated global session value to DynamoDB
  dynamodb$put_item(
    TableName = dynamodb_table_name,
    Item = list(
      "MetricName" = list(S = "ActiveSessions"),
      "Value" = list(N = as.character(current_value))
    )
  )
  
  # Send updated metrics to CloudWatch
  response <- cloudwatch$put_metric_data(
    Namespace = "ShinyApp",
    MetricData = list(
      # Metric for sessions per task
      list(
        MetricName = "SessionsPerTask",
        Value = sessions_per_task,
        Unit = "Count",
        Dimensions = list(
          list(Name = "Application", Value = "ShinyApp")
        )
      )
    )
  )
  
  # Log the updates
  cat("Updated global ActiveSessions count to in DynamoDB:", current_value, "\n")
  cat("Reported SessionsPerTask to CloudWatch:", sessions_per_task, "\n")
  cat("Number of tasks in the cluster:", task_count, "\n")

  return(response)
}
