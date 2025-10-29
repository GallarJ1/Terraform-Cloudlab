variable "project" {
  type    = string
  default = "MyLab"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "location" {
  type    = string
  default = "centralus"
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "app_runtime" {
  type    = string
  default = "18-lts" # <-- Azure Linux Web Apps expect "18-lts" or "20-lts"
}

variable "plan_sku" {
  type    = string
  default = "B1"
}

variable "sql_admin_login" {
  type    = string
  default = "sqladminuser"
}
