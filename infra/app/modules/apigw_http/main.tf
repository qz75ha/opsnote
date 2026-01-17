resource "aws_apigatewayv2_api" "http" {
  name          = "${var.name_prefix}-http-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = var.cors_allow_origins
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["content-type"]
  }
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http.id
  name        = "$default"
  auto_deploy = true
}

# Integrations
resource "aws_apigatewayv2_integration" "create" {
  api_id           = aws_apigatewayv2_api.http.id
  integration_type = "AWS_PROXY"
  integration_uri  = var.create_fn_invoke_arn
}

resource "aws_apigatewayv2_integration" "list" {
  api_id           = aws_apigatewayv2_api.http.id
  integration_type = "AWS_PROXY"
  integration_uri  = var.list_fn_invoke_arn
}

resource "aws_apigatewayv2_integration" "get" {
  api_id           = aws_apigatewayv2_api.http.id
  integration_type = "AWS_PROXY"
  integration_uri  = var.get_fn_invoke_arn
}

# Routes
resource "aws_apigatewayv2_route" "create" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "POST /items"
  target    = "integrations/${aws_apigatewayv2_integration.create.id}"
}

resource "aws_apigatewayv2_route" "list" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "GET /items"
  target    = "integrations/${aws_apigatewayv2_integration.list.id}"
}

resource "aws_apigatewayv2_route" "get" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "GET /items/{id}"
  target    = "integrations/${aws_apigatewayv2_integration.get.id}"
}

# Lambda permissions (API Gateway -> Lambda invoke)
resource "aws_lambda_permission" "create" {
  statement_id  = "AllowInvokeCreate"
  action        = "lambda:InvokeFunction"
  function_name = var.create_fn_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}

resource "aws_lambda_permission" "list" {
  statement_id  = "AllowInvokeList"
  action        = "lambda:InvokeFunction"
  function_name = var.list_fn_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}

resource "aws_lambda_permission" "get" {
  statement_id  = "AllowInvokeGet"
  action        = "lambda:InvokeFunction"
  function_name = var.get_fn_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}
