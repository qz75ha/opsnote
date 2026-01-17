data "aws_region" "current" {}

# --- Zip packaging (Python想定) ---
data "archive_file" "create_zip" {
  type        = "zip"
  source_file = "${var.lambda_src_root}/create_item.py"
  output_path = "${path.module}/build/create_item.zip"
}

data "archive_file" "list_zip" {
  type        = "zip"
  source_file = "${var.lambda_src_root}/list_items.py"
  output_path = "${path.module}/build/list_items.zip"
}

data "archive_file" "get_zip" {
  type        = "zip"
  source_file = "${var.lambda_src_root}/get_item.py"
  output_path = "${path.module}/build/get_item.zip"
}

# --- IAM role for lambdas ---
resource "aws_iam_role" "lambda_role" {
  name = "${var.name_prefix}-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# CloudWatch Logs (basic)
resource "aws_iam_role_policy" "logs" {
  name = "${var.name_prefix}-lambda-logs"
  role = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = "arn:aws:logs:${data.aws_region.current.name}:*:log-group:/aws/lambda/*"
    }]
  })
}

# DynamoDB access（最小：CRUDのうち当面 Put + Get + Query）
resource "aws_iam_role_policy" "ddb" {
  name = "${var.name_prefix}-lambda-ddb"
  role = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:PutItem",
        "dynamodb:GetItem",
        "dynamodb:Query"
      ]
      Resource = [
        var.table_arn,
        "${var.table_arn}/index/*"
      ]
    }]
  })
}

# --- Lambda functions ---
locals {
  runtime = "python3.12"
}

resource "aws_lambda_function" "create" {
  function_name = "${var.name_prefix}-create-item"
  role          = aws_iam_role.lambda_role.arn
  handler       = "create_item.handler"
  runtime       = local.runtime
  filename      = data.archive_file.create_zip.output_path

  environment {
    variables = {
      TABLE_NAME = var.table_name
    }
  }
}

resource "aws_lambda_function" "list" {
  function_name = "${var.name_prefix}-list-items"
  role          = aws_iam_role.lambda_role.arn
  handler       = "list_items.handler"
  runtime       = local.runtime
  filename      = data.archive_file.list_zip.output_path

  environment {
    variables = {
      TABLE_NAME = var.table_name
      GSI_NAME   = "gsi1"
      GSI_PK     = "ITEM"
    }
  }
}

resource "aws_lambda_function" "get" {
  function_name = "${var.name_prefix}-get-item"
  role          = aws_iam_role.lambda_role.arn
  handler       = "get_item.handler"
  runtime       = local.runtime
  filename      = data.archive_file.get_zip.output_path

  environment {
    variables = {
      TABLE_NAME = var.table_name
    }
  }
}

# --- Log retention ---
resource "aws_cloudwatch_log_group" "create" {
  name              = "/aws/lambda/${aws_lambda_function.create.function_name}"
  retention_in_days = var.log_retention_days
}

resource "aws_cloudwatch_log_group" "list" {
  name              = "/aws/lambda/${aws_lambda_function.list.function_name}"
  retention_in_days = var.log_retention_days
}

resource "aws_cloudwatch_log_group" "get" {
  name              = "/aws/lambda/${aws_lambda_function.get.function_name}"
  retention_in_days = var.log_retention_days
}

# --- Minimal alarms (action無しでも “検知” は学習になる) ---
resource "aws_cloudwatch_metric_alarm" "create_errors" {
  alarm_name          = "${var.name_prefix}-create-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 0

  dimensions = {
    FunctionName = aws_lambda_function.create.function_name
  }
}

resource "aws_cloudwatch_metric_alarm" "list_errors" {
  alarm_name          = "${var.name_prefix}-list-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 0

  dimensions = {
    FunctionName = aws_lambda_function.list.function_name
  }
}

resource "aws_cloudwatch_metric_alarm" "get_errors" {
  alarm_name          = "${var.name_prefix}-get-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 0

  dimensions = {
    FunctionName = aws_lambda_function.get.function_name
  }
}
