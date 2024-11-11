# Request SSL Certificate in ACM
resource "aws_acm_certificate" "alb_ssl_cert" {
  domain_name       = var.domain_name                # Use domain from variables
  validation_method = "DNS"                          # Use DNS for validation

  subject_alternative_names = ["www.${var.domain_name}"]

  tags = {
    Environment = var.env
  }
}

# Output the certificate ARN for reference
output "ssl_certificate_arn" {
  value = aws_acm_certificate.alb_ssl_cert.arn
}
