variable "name_prefix" { type = string }
variable "table_name" { type = string }
variable "table_arn" { type = string }
variable "lambda_src_root" { type = string }
variable "log_retention_days" { type = number }
variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags to apply to resources in this module"
}
