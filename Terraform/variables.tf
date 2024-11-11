# VPC ID for the environment
variable "vpc_id" {
  description = "VPC ID for deploying the ECS service"
  type        = string
  default     = "vpc-0043ac430c598fb8e"  # Set to your current VPC ID
}

# Subnets for ECS tasks
variable "subnets" {
  description = "Subnets to deploy ECS tasks into"
  type        = list(string)
  default     = [
    "subnet-09afd8f0ab5610eac",
    "subnet-04e03ea35db1088f9",
    "subnet-0112a3d65fc186ba1",
    "subnet-02320b76f565eb4c1",
    "subnet-02b46bbf568bed404",
    "subnet-0688ccd0da8365064"
  ]
}

# Port for the Shiny app
variable "container_port" {
  description = "Port on which the Shiny app will run"
  type        = number
  default     = 3838  # Shiny default port
}

# Environment name (e.g., dev, prod)
variable "env" {
  description = "Deployment environment (e.g., dev, prod)"
  type        = string
  default     = "dev"
}

# Domain name for the SSL certificate
variable "domain_name" {
  description = "Domain name for the SSL certificate"
  type        = string
  default     = "jonah-sandbox.ahmedjou.com"
}
