variable "name_prefix" { type = string }

variable "tags" {
  description = "Tags applied to taggable resources (includes awsApplication for AppRegistry)."
  type        = map(string)
  default     = {}
}
