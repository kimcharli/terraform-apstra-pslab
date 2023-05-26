locals {
  managed_devices = yamldecode(file("${path.module}/../main/config.yaml")).managed_device
}

data "apstra_agent_profiles" "all" {}

data "apstra_agent_profile" "each" {
  for_each = data.apstra_agent_profiles.all.ids
  id       = each.key
}

locals {
    device_map = flatten([
        # iterate managed_devices for each profile_name and its device_list
        for profile_name, device_list in local.managed_devices: [
            # retrieve the agent_profile_id from the profile name
            for agent_profile in data.apstra_agent_profile.each: [
              # compose the list of map of id and ip
              for ip in device_list:
                {
                  id = agent_profile.id
                  ip = ip
                }
            ]
        ] 
    ])
}


resource "apstra_managed_device" "all" {
  count = length(local.device_map)
  agent_profile_id = local.device_map[count.index].id
  off_box = true
  management_ip = local.device_map[count.index].ip
}

resource "apstra_managed_device_ack" "all" {
  count = length(local.device_map)
  agent_id = apstra_managed_device.all[count.index].agent_id
  device_key = apstra_managed_device.all[count.index].system_id
}

output "ip_to_serial_number" {
    value = { for managed_device in apstra_managed_device.all : managed_device.management_ip => managed_device.system_id }
}
