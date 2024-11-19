# 1. Create a DynamoDB table to store the global value of Active ActiveSessions
resource "aws_dynamodb_table" "active_sessions" {
  name           = "${var.env}-active-sessions"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "MetricName"

  attribute {
    name = "MetricName"
    type = "S"
  }
}