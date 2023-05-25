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

module "managed_device" {
    source = "./managed_device"
    id_to_ip = jsonencode(local.device_map)
}

output "ip_to_serial_number" {
  value = module.managed_device.ip_to_serial_number
}