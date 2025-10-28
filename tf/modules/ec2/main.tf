resource "aws_instance" "instances" {
  for_each = var.instances
  
  ami             = each.value.ami_id
  instance_type   = each.value.instance_type
  subnet_id       = each.value.subnet_id
  security_groups = each.value.security_group_ids
  key_name        = each.value.key_name

  root_block_device {
    volume_size = each.value.volume_size
    volume_type = "gp2"
    encrypted   = true
  }

  tags = merge(
    var.common_tags,
    {
      Name = each.value.name
      Type = each.value.type
    }
  )
  
  lifecycle {
    create_before_destroy = true
  }
} 