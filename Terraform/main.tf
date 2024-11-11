provider "aws" {
  region = "us-east-1"
}

# 1. ECR Repository
resource "aws_ecr_repository" "shiny_repository" {
  name = "shiny-repository"  # Name of the ECR repository
}

# 2. Define an ECS Cluster to host the Shiny app
resource "aws_ecs_cluster" "shiny_cluster" {
  name = "shiny-cluster" # Name of the ECS cluster
}

# 3. Define a security group to control access to the ECS service
resource "aws_security_group" "ecs_security_group" {
  name        = "${var.env}-ecs-shiny-security-group"
  description = "Allow inbound traffic to ECS service for R Shiny app"
  vpc_id      = var.vpc_id  # Use the VPC ID from variables.tf

  # Inbound rule to allow HTTP access to the specified app port (e.g., 3838 for Shiny)
  ingress {
    from_port   = var.container_port       # App port (3838 by default)
    to_port     = var.container_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]      # Open to all IPs; adjust for production security
  }
  
  # Outbound rule to allow all outgoing traffic (e.g., internet access)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"               # all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 4. IAM Role for ECS Task Execution
# This IAM role allows ECS tasks to pull images from ECR and log to CloudWatch. 
# It is configured to be environment-specific, using the `var.env` variable.
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.env}-ecsTaskExecutionRole"  # Environment-specific name for easier management (e.g., dev-ecsTaskExecutionRole)

  # Trust policy allowing ECS tasks to assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = "sts:AssumeRole",
      Principal = {
        Service = "ecs-tasks.amazonaws.com"  # ECS tasks can assume this role
      }
    }]
  })
}

# Attach the necessary ECS execution policy to the IAM role
resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name  # Role to attach policy to
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"  # Grants ECR and CloudWatch access
}

# 5. Define an ECS Task Definition for the Shiny app
resource "aws_ecs_task_definition" "shiny_task" {
  family                   = "${var.env}-shiny-task"   # Environment-specific name for the task definition
  network_mode             = "awsvpc"                          # Required for Fargate
  requires_compatibilities = ["FARGATE"]                       # Specifies Fargate as the launch type
  cpu                      = "512"                             # CPU resources for the task (adjust as needed)
  memory                   = "1024"                            # Memory resources for the task (adjust as needed)
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn  # IAM role for task execution

  # Define the container details for the Shiny app
  container_definitions = jsonencode([
    {
      name      = "shiny-container"                            # Name of the container
      image     = "${aws_ecr_repository.shiny_repository.repository_url}:latest"  # ECR image URI
      essential = true                                         # Marks the container as essential for the task

      portMappings = [{                                        # Map container port for Shiny app
        containerPort = var.container_port                           # Use the port defined in variables (e.g., 3838)
        hostPort      = var.container_port
      }]

      logConfiguration = {                                     # Send logs to CloudWatch
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/${var.env}-shiny-app"  # Log group in CloudWatch
          awslogs-region        = "us-east-1"
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

# 6. Define an ECS Service to run the Shiny app on Fargate
resource "aws_ecs_service" "shiny_fargate_service" {
  name            = "${var.env}-shiny-service"        # Environment-specific name for the service
  cluster         = aws_ecs_cluster.shiny_cluster.id          # Reference to the ECS cluster
  task_definition = aws_ecs_task_definition.shiny_task.arn    # Task definition for the Shiny app
  launch_type     = "FARGATE"                                 # Specifies Fargate as the launch type
  desired_count   = 1                                         # Number of tasks to run; adjust as needed

  network_configuration {
    subnets         = var.subnets                             # Subnets from variables.tf
    security_groups = [aws_security_group.ecs_security_group.id]  # Reference to the security group
    assign_public_ip = true                                   # Assigns a public IP for access over the internet
  }

  # Associate the ECS service with the ALB target group
  load_balancer {
    target_group_arn = aws_lb_target_group.shiny_lb_target_group.arn  # Reference to the target group
    container_name   = "shiny-container"                           # Name of the container in the task definition
    container_port   = var.container_port                          # Container port (e.g., 3838)
  }

  depends_on = [aws_iam_role_policy_attachment.ecs_task_execution_policy]  # Ensures the role is attached before service creation
}

# 7. Create a CloudWatch Log Group for ECS Task Logs
resource "aws_cloudwatch_log_group" "ecs_log_group" {
  name              = "/ecs/${var.env}-shiny-app"          # Log group name using the environment prefix
  retention_in_days = 7                                    # Set retention to 7 days (adjust as needed)
}

