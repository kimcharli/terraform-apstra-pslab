variable "id_to_ip" {}

locals {
    id_to_ip_list = jsondecode(var.id_to_ip)
}

resource "apstra_managed_device" "all" {
    count = length(local.id_to_ip_list)
    agent_profile_id = local.id_to_ip_list[count.index].id
    off_box = true
    management_ip = local.id_to_ip_list[count.index].ip
}

output "ip_to_serial_number" {
    value = { for managed_device in apstra_managed_device.all : managed_device.management_ip => managed_device.system_id }
}


