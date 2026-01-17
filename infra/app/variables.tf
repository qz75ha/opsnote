variable "region" {
  type    = string
  default = "ap-northeast-1"
}

variable "project" {
  type    = string
  default = "opsnote"
}

variable "env" {
  type    = string
  default = "dev"
}

variable "tags" {
  type = map(string)
  default = {
    Project = "opsnote"
    Env     = "dev"
  }
}

variable "cors_allow_origins" {
  type = list(string)
  default = [
    "https://dr5272oen0ylg.cloudfront.net"
  ]
}


variable "log_retention_days" {
  type    = number
  default = 14
}
