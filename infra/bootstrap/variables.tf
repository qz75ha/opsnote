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
