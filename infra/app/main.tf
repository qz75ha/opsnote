locals {
  name_prefix = "${var.project}-${var.env}"
}

module "dynamodb" {
  source      = "./modules/dynamodb"
  name_prefix = local.name_prefix
}

module "lambda" {
  source             = "./modules/lambda"
  name_prefix        = local.name_prefix
  table_name         = module.dynamodb.table_name
  table_arn          = module.dynamodb.table_arn
  log_retention_days = var.log_retention_days

  # Lambda ソースのパス（repo ルート基準で app/lambda を参照する想定）
  lambda_src_root = "${path.module}/../../app/lambda"
}

module "apigw" {
  source             = "./modules/apigw_http"
  name_prefix        = local.name_prefix
  cors_allow_origins = var.cors_allow_origins

  create_fn_invoke_arn = module.lambda.create_fn_invoke_arn
  list_fn_invoke_arn   = module.lambda.list_fn_invoke_arn
  get_fn_invoke_arn    = module.lambda.get_fn_invoke_arn

  create_fn_name = module.lambda.create_fn_name
  list_fn_name   = module.lambda.list_fn_name
  get_fn_name    = module.lambda.get_fn_name
}

module "frontend" {
  source      = "./modules/frontend_s3"
  name_prefix = local.name_prefix
}
