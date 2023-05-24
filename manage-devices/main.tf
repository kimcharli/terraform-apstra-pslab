locals {
  devices = yamldecode(file("${path.module}/../config.yaml")).managed_device
}


data "apstra_agent_profiles" "all" {}

data "apstra_agent_profile" "each" {
  for_each = data.apstra_agent_profiles.all.ids
  id       = each.key
}

locals {
    profile_ids = flatten([
        for profile_name, devices in local.devices: [
            for agent_profile in data.apstra_agent_profile.each: {
                id = agent_profile.id
                devices = devices               
            } if agent_profile.name == profile_name
        ] 

    ])
}

# need to have seperate module per agent profile
module "profile-0" {
    source = "./devices"
    # for_each = local.profile_ids # cannot use in module
    agent_profile_id = local.profile_ids.0.id
    management_ips = local.profile_ids.0.devices
}


# output "devices" {
#     value = local.devices
# }

# output "agents" {
#     value = data.apstra_agent_profile.each
# }

# output "profile_ids" {
#     value = local.profile_ids
# }

# output "profiles" {
#     value = local.profiles
# }

output "serial-serial_number-0" {
  value = module.profile-0.serial_number
}