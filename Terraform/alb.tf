# 1. Create an Application Load Balancer (ALB) for the ECS service
resource "aws_lb" "shiny_alb" {
  name               = "${var.env}-shiny-alb"  # Environment-specific name for easier management
  internal           = false                   # Set to false to make ALB internet-facing
  load_balancer_type = "application"           # Specifies ALB (Application Load Balancer)
  security_groups    = [aws_security_group.alb_security_group.id]  # Attach security group for traffic control
  subnets            = var.subnets             # Subnets in which to deploy the ALB

  enable_deletion_protection = false           # For production environments, consider setting this to true to avoid accidental deletion
  
  # Enable logging to the S3 bucket # TODO: fix security issue with bucket policy
  # access_logs {
  #   enabled = true
  #   bucket  = aws_s3_bucket.alb_logs.bucket  # Reference the created S3 bucket for logs
  #   prefix  = "alb-logs"                     # Optional: Specify a folder (prefix) in the S3 bucket
  # }
}

# 2. ALB Security Group
resource "aws_security_group" "alb_security_group" {
  name        = "${var.env}-alb-security-group"
  description = "Security group for ALB to allow inbound HTTPS traffic"
  vpc_id      = var.vpc_id

  # Inbound rule to allow HTTPS access (port 443) from any IP
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Open to all IPs; restrict as needed for production security
  }

  # Outbound rule to allow all outgoing traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # All protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.env}-alb-security-group"
  }
}

# 3. Create an ALB Listener with SSL certificate and Cognito authentication
resource "aws_lb_listener" "shiny_alb_listener" {
  load_balancer_arn = aws_lb.shiny_alb.arn     # Associate listener with the ALB created above
  port              = 443                      # Use HTTPS (port 443) for secure access
  protocol          = "HTTPS"                  # Specify HTTPS protocol for SSL/TLS encryption
  ssl_policy        = "ELBSecurityPolicy-2016-08"  # Use a predefined secure SSL policy
  certificate_arn   = aws_acm_certificate.alb_ssl_cert.arn  # Attach the SSL certificate from ACM

  # Default actions: Authenticate with Cognito, then forward to the target group
  
  default_action {
    type = "authenticate-cognito"             # Add Cognito authentication
 
    # Cognito authentication configuration
    authenticate_cognito {
      user_pool_arn       = aws_cognito_user_pool.user_pool.arn          # Reference the Cognito User Pool
      user_pool_client_id = aws_cognito_user_pool_client.user_pool_client.id  # Reference the User Pool Client
      user_pool_domain    = aws_cognito_user_pool_domain.auth_domain.domain   # Cognito User Pool Domain
    }
  }

  default_action {
    type             = "forward"                # Forward traffic to target group
    target_group_arn = aws_lb_target_group.shiny_lb_target_group.arn  # Target group to forward to
  }
}

# 4. Define a Target Group for the ECS service
resource "aws_lb_target_group" "shiny_lb_target_group" {
  name        = "${var.env}-shiny-tg"          # Environment-specific name for the target group
  port        = var.container_port             # Use container port from variable (e.g., 3838)
  protocol    = "HTTP"                         # Set protocol to HTTP; SSL termination handled by ALB
  vpc_id      = var.vpc_id                     # Use the specified VPC for target group
  target_type = "ip"                           # Required target type for Fargate (uses IPs directly)
  
  deregistration_delay = 3600  # The number of seconds to wait before considering a target as fully deregistered
  
  # Health check configuration for ECS tasks
  health_check {
    path                = "/"                  # Health check endpoint (adjust if needed)
    interval            = 30                   # Health check interval in seconds
    timeout             = 5                    # Health check timeout in seconds
    healthy_threshold   = 2                    # Number of successful checks to mark as healthy
    unhealthy_threshold = 2                    # Number of failures to mark as unhealthy
    matcher             = "200"                # Expected HTTP status code for a healthy response
  }
  
  # Stickiness configuration
  stickiness {
    enabled          = true                     # Enable stickiness
    type             = "lb_cookie"              # Use ALB-generated cookies for stickiness
    cookie_duration  = 20                    # Duration (in seconds) for cookie validity - 1 Day
  }
}
