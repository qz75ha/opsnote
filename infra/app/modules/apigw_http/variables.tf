variable "name_prefix" { type = string }

variable "cors_allow_origins" { type = list(string) }

variable "create_fn_invoke_arn" { type = string }
variable "list_fn_invoke_arn" { type = string }
variable "get_fn_invoke_arn" { type = string }

variable "create_fn_name" { type = string }
variable "list_fn_name" { type = string }
variable "get_fn_name" { type = string }

variable "tags" {
  description = "Tags applied to taggable resources (includes awsApplication for AppRegistry)."
  type        = map(string)
  default     = {}
}