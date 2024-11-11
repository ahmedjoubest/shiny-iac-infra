# 1. Create an Application Load Balancer (ALB) for the ECS service
resource "aws_lb" "shiny_alb" {
  name               = "${var.env}-shiny-alb"  # Environment-specific name for easier management
  internal           = false                   # Set to false to make ALB internet-facing
  load_balancer_type = "application"           # Specifies ALB (Application Load Balancer)
  security_groups    = [aws_security_group.ecs_security_group.id]  # Attach security group for traffic control
  subnets            = var.subnets             # Subnets in which to deploy the ALB

  enable_deletion_protection = false           # Disable deletion protection; adjust if needed for production
}

# 2. Create an ALB Listener with SSL certificate
resource "aws_lb_listener" "shiny_alb_listener" {
  load_balancer_arn = aws_lb.shiny_alb.arn     # Associate listener with the ALB created above
  port              = 443                      # Use HTTPS (port 443) for secure access
  protocol          = "HTTPS"                  # Specify HTTPS protocol for SSL/TLS encryption
  ssl_policy        = "ELBSecurityPolicy-2016-08"  # Use a predefined secure SSL policy
  certificate_arn   = aws_acm_certificate.alb_ssl_cert.arn  # Attach the SSL certificate from ACM

  # Default action: forward incoming traffic to the target group
  default_action {
    type             = "forward"                # Forward traffic to target group
    target_group_arn = aws_lb_target_group.shiny_lb_target_group.arn  # Target group to forward to
  }
}

# 3. Define a Target Group for the ECS service
resource "aws_lb_target_group" "shiny_lb_target_group" {
  name        = "${var.env}-shiny-tg"          # Environment-specific name for the target group
  port        = var.container_port             # Use container port from variable (e.g., 3838)
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