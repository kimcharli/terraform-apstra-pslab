
#### logical_device
locals {
  devices = yamldecode(file("${path.module}/config.yaml")).logical_device
}


resource "apstra_logical_device" "all" {
  for_each = local.devices
  name = each.value.name
  panels = each.value.panels
} 


#### interface_map
locals {
  interface_maps = yamldecode(file("${path.module}/config.yaml")).interface_map
}

resource "apstra_interface_map" "all" {
  for_each = local.interface_maps
  name = each.value.name
  logical_device_id = apstra_logical_device.all[each.value.logical_device].id
  device_profile_id = each.value.device_profile_id
  interfaces        = flatten([
    for map in each.value.device_mapping : [
      for i in range(map.count) : {
        logical_device_port     = format("%d/%d", map.ld_panel, map.ld_first_port + i)
        physical_interface_name = format("%s%d", map.phy_prefix, map.phy_first_port + i)
      }
    ]
  ])
}


#### device allocation

locals {
  device_allocation_list = flatten([
    for bp_label, bp in yamldecode(file("${path.module}/config.yaml")).blueprint : [
      for device_label, device in bp.device_allocation : {
        bp_label = bp_label
        node_name = device_label
        device_key = device.device_key
        interface_map = device.interface_map
        }
    ]
  ])
  device_allocation_dict = {
    for device in local.device_allocation_list : device.node_name => device
  }

}


# Assign interface maps to fabric roles to eliminate build errors so we can deploy
resource "apstra_datacenter_device_allocation" "all" {
  depends_on = [ 
    apstra_interface_map.all, 
    apstra_datacenter_blueprint.all
    ]
  for_each = local.device_allocation_dict
  blueprint_id     = apstra_datacenter_blueprint.all[each.value.bp_label].id
  node_name        = each.key
  device_key       = each.value.device_key
  interface_map_id = apstra_interface_map.all[each.value.interface_map].id
  deploy_mode      = "deploy"
}

