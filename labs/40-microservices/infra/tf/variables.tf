# Sets global variables for this Terraform project.
variable app_name {
  type = string
  default = "bmwdkFlixtube"
}

variable location {
type = string
  default = "eastus"
}

variable kubernetes_version {
  type = string
  default = "1.35"
}
