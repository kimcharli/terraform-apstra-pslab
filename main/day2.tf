#### rack

locals {
#   blueprint = yamldecode(file("${path.module}/config.yaml")).blueprint  # from blurprint
  routing_zones = flatten([ 
    for bp_label, bp in local.blueprint : [
      for rz_label, rz in bp.routing_zones: {
        name = rz_label
        blueprint_id = apstra_datacenter_blueprint.all[bp_label].id
        vlan_id = rz.vlan_id
        vni = rz.vni
        dhcp_servers = rz.dhcp_servers
      }
    ]
  ])
}


# 
# 
# locals {
#     device_map = flatten([
#         # iterate managed_devices for each profile_name and its device_list
#         for profile_name, device_list in local.managed_devices: [
#             # retrieve the agent_profile_id from the profile name
#             for agent_profile in data.apstra_agent_profile.each: [
#               # compose the list of map of id and ip
#               for ip in device_list:
#                 {
#                   id = agent_profile.id
#                   ip = ip
#                 }
#             ]
#         ] 
#     ])
# }
# 



resource "apstra_datacenter_routing_zone" "all" {
  depends_on = [ apstra_blueprint_deployment.deploy ]
  count = length(local.routing_zones)
  # for_each = local.routing_zones
  name = local.routing_zones[count.index].name
  blueprint_id =  local.routing_zones[count.index].blueprint_id
  vlan_id = local.routing_zones[count.index].vlan_id
  vni = local.routing_zones[count.index].vni
  dhcp_servers = local.routing_zones[count.index].dhcp_servers  
}





