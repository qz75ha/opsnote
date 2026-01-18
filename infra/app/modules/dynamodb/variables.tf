variable "name_prefix" { type = string }

variable "tags" {
  description = "Tags to apply to resources in this module"
  type        = map(string)
  default     = {}
}
