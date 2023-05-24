variable "agent_profile_id" {}

variable "management_ips" {
    type = list
}

resource "apstra_managed_device" "device" {
    for_each = toset(var.management_ips)
    agent_profile_id = var.agent_profile_id
    off_box = true
    management_ip = each.key
}

output "management_ips" {
  value = var.management_ips
}

output "serial_number" {
    # value = apstra_managed_device.device[*]
    value = { for ip, data in apstra_managed_device.device : ip => data.system_id }
}


