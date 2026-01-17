output "api_endpoint" {
  value = module.apigw.api_endpoint
}

output "frontend_url" {
  value = "https://${module.frontend.cloudfront_domain_name}"
}

output "frontend_bucket" {
  value = module.frontend.bucket_name
}

output "dynamodb_table" {
  value = module.dynamodb.table_name
}
