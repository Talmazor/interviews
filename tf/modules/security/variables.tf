variable "vpc_id" {
  description = "VPC ID where the security group will be created"
  type        = string
}

variable "allowed_ports" {
  description = "Allowed ingress ports with descriptions"
  type        = map(object({
    port        = number
    description = string
  }))
}

variable "common_tags" {
  description = "Common tags to be applied to all resources"
  type        = map(string)
}