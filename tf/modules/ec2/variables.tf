variable "instances" {
  description = "Map of EC2 instances to create"
  type = map(object({
    name              = string
    type              = string
    ami_id            = string
    instance_type     = string
    subnet_id         = string
    security_group_ids = list(string)
    key_name          = string
    volume_size       = number
  }))
}

variable "common_tags" {
  description = "Common tags to be applied to all resources"
  type        = map(string)
} 