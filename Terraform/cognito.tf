# 1. Create a Cognito User Pool
# The user pool manages authentication and user attributes for the application.
resource "aws_cognito_user_pool" "user_pool" {
  name = "${var.env}-user-pool"  # Name of the user pool, prefixed with the environment (e.g., dev, prod).

  # Define the attributes required during user registration and login
  schema {
    name     = "email"                      # Email is required and immutable.
    required = true
    mutable  = false
    attribute_data_type = "String"
  }

  schema {
    name     = "given_name"                 # First name field.
    required = true
    mutable  = true
    attribute_data_type = "String"
  }

  schema {
    name     = "family_name"                # Last name field.
    required = true
    mutable  = true
    attribute_data_type = "String"
  }

  schema {
    name     = "phone_number"               # Optional phone number field.
    required = false
    mutable  = true
    attribute_data_type = "String"
  }

  schema {
  name     = "custom:role"
  required = false
  mutable  = true
  attribute_data_type = "String"
  }

  schema {
    name     = "custom:type"
    required = false
    mutable  = true
    attribute_data_type = "String"
  }

  # Alias and verification settings
  alias_attributes = ["email"]             # Users log in with their email address.
  auto_verified_attributes = ["email"]     # Email is automatically verified during registration.
  mfa_configuration = "OFF"                # Multi-factor authentication is disabled.

  # Configure email verification messages
  verification_message_template {
    default_email_option = "CONFIRM_WITH_CODE"  # Users verify their email using a confirmation code.
  }

  # Configuration for user creation
  admin_create_user_config {
    allow_admin_create_user_only = false   # Public sign-ups are allowed (not restricted to admin).
  }
  
  # Ignore updates to schema after the resource is created
  # Otherwise 'terraform apply' crashes after the first run
  lifecycle {
    ignore_changes = [schema]
  }
}
# Define a Cognito User Pool Domain
resource "aws_cognito_user_pool_domain" "auth_domain" {
  domain       = "${var.env}-auth-domain"                 # Unique domain name for authentication
  user_pool_id = aws_cognito_user_pool.user_pool.id       # Reference the Cognito User Pool
}

# 2. Define a User Pool Client
# This client represents the application that interacts with the Cognito user pool.
resource "aws_cognito_user_pool_client" "user_pool_client" {
  name           = "${var.env}-user-pool-client"  # Name of the client, prefixed with the environment.
  user_pool_id   = aws_cognito_user_pool.user_pool.id  # Reference to the Cognito user pool.
  generate_secret = true                          # Client secret is not required for public access.

  # URLs for redirecting users after login or logout
  callback_urls = [var.callback_url]              # URL users are redirected to after successful login.
  logout_urls   = [var.logout_url]                # URL users are redirected to after logging out.

  # OAuth settings
  allowed_oauth_flows = ["code"]                  # Authorization code grant flow for secure authentication.
  allowed_oauth_scopes = [
    "email",                                      # Access to email information.
    "openid",                                     # Access to OpenID Connect standard claims.
    "aws.cognito.signin.user.admin"               # Access to manage user accounts within Cognito.
  ]
  supported_identity_providers = ["COGNITO"]      # Only Cognito is used as an identity provider.
  
  # Enable OAuth flows explicitly
  allowed_oauth_flows_user_pool_client = true    # Allow the client to use OAuth flows.
  
  # Allow custom attributes to be included in authentication tokens
  # write_attributes = [
  #   "custom:role",                                # Pass the custom role attribute in tokens.
  #   "custom:type"                                 # Pass the custom type attribute in tokens.
  # ]
}

# 3. IAM Role for Cognito
# This role allows the Cognito Identity Provider (IDP) to assume permissions for session management.
resource "aws_iam_role" "cognito_idp_role" {
  name = "${var.env}-cognito-idp-role"            # Environment-specific name for easier identification.

  # Trust policy to allow Cognito IDP to assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "cognito-idp.amazonaws.com"   # Cognito Identity Provider service as the trusted entity.
        },
        Action = "sts:AssumeRole"                # Allows Cognito to assume this role.
      }
    ]
  })
}

# 4. Outputs for Cognito
# These outputs expose key information needed to integrate with the Cognito user pool.

# Output the Cognito User Pool ID
output "user_pool_id" {
  description = "ID of the Cognito User Pool"
  value       = aws_cognito_user_pool.user_pool.id
}

# Output the Cognito User Pool Client ID
output "user_pool_client_id" {
  description = "ID of the Cognito User Pool Client"
  value       = aws_cognito_user_pool_client.user_pool_client.id
}

# Output the IAM Role ARN for Cognito Identity Provider
output "cognito_idp_role_arn" {
  description = "ARN of the IAM Role for Cognito Identity Provider"
  value       = aws_iam_role.cognito_idp_role.arn
}

# Output the Cognito User Pool Domain
output "cognito_auth_domain" {
  description = "Cognito User Pool Domain"
  value       = aws_cognito_user_pool_domain.auth_domain.domain
}

# 5. logout resources for the logout HTTP server - Plumber

# 5.a ECR repository for the logout server
# Create an ECR repository 
resource "aws_ecr_repository" "logout_server" {
 name = "logout-server"  # Name of the ECR repository
}

# 5.b Task definition for the logout server
resource "aws_ecs_task_definition" "logout_server" {
 family                   = "${var.env}-logout-server"   # Environment-specific name for the task definition
 network_mode             = "awsvpc"                          # Required for Fargate
 requires_compatibilities = ["FARGATE"]                       # Specifies Fargate as the launch type
 cpu                      = "512"                             # CPU resources for the task (adjust as needed)
 memory                   = "1024"                            # Memory resources for the task (adjust as needed)
 execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn  # IAM role for task execution
 
 # Define the container details for the Shiny app
 container_definitions = jsonencode([
   {
     name      = "logout-server-container"                            # Name of the container
     image     = "${aws_ecr_repository.logout_server.repository_url}:latest"  # ECR image URI
     essential = true                                         # Marks the container as essential for the task
     
     portMappings = [{                                        # Map container port for Shiny app
       containerPort = 6030
       hostPort      = 6030
     }]
     
     # TODO: add logConfiguration for the container (avoided for crash)
   }
 ])
}

# 5.c Service definition for the logout server
resource "aws_ecs_service" "fargate_logout_server" {
 name            = "${var.env}-logout-server-service"        # Environment-specific name for the service
 cluster         = aws_ecs_cluster.shiny_cluster.id          # Reference to the ECS cluster
 task_definition = aws_ecs_task_definition.logout_server.arn    # Task definition for the Shiny app
 launch_type     = "FARGATE"                                 # Specifies Fargate as the launch type
 desired_count   = 1                                         # Number of tasks to run; adjust as needed
 
 network_configuration {
   subnets         = var.subnets                             # Subnets from variables.tf
   security_groups = [aws_security_group.ecs_security_group.id]  # Reference to the security group
   assign_public_ip = true                                   # if we want to apply = false, we should use private subnets
 }
 
 # Associate the ECS service with the ALB target group
 load_balancer {
   target_group_arn = aws_lb_target_group.logout_lb_target_group.arn  # Reference to the target group
   container_name   = "logout-server-container"                           # Name of the container in the task definition
   container_port   = 6030
 }
 
 depends_on = [aws_iam_role_policy_attachment.ecs_task_execution_policy]  # Ensures the role is attached before service creation
}

# 5.d target group for the logout server
resource "aws_lb_target_group" "logout_lb_target_group" {
 name        = "${var.env}-logout-tg"          # Environment-specific name for the target group
 port        = 6030            # Use container port from variable (e.g., 3838)
 protocol    = "HTTP"                         # Set protocol to HTTP; SSL termination handled by ALB
 vpc_id      = var.vpc_id                     # Use the specified VPC for target group
 target_type = "ip"                           # Required target type for Fargate (uses IPs directly)

 # Health check configuration for ECS tasks
 health_check {
   path                = "/"                  # Health check endpoint (adjust if needed)
   interval            = 30                   # Health check interval in seconds
   timeout             = 5                    # Health check timeout in seconds
   healthy_threshold   = 2                    # Number of successful checks to mark as healthy
   unhealthy_threshold = 2                    # Number of failures to mark as unhealthy
   matcher             = "200"                # Expected HTTP status code for a healthy response
 }
}

# 5.e listener rule for the logout server on "/logout"
resource "aws_lb_listener_rule" "logout_listener_rule" {
 listener_arn = aws_lb_listener.shiny_alb_listener.arn
 priority = 100
 action {
   type = "forward"
   target_group_arn = aws_lb_target_group.logout_lb_target_group.arn
 }
 condition {
   path_pattern {
     values = ["/logout"]
   }
 }
}
