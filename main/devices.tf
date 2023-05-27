locals {
  devices = yamldecode(file("${path.module}/config.yaml")).logical_device
  device_group_list = [ for k, v in local.devices : k ]
}


#### logical_device
resource "apstra_logical_device" "all" {
  for_each = { for i, name in local.device_group_list: i => name }
  name = local.devices[each.value].name
  panels = local.devices[each.value].panels
} 


#### interface_map
resource "apstra_interface_map" "all" {
  for_each = { for i, name in local.device_group_list: i => name }
  name = local.devices[each.value].name
  logical_device_id = apstra_logical_device.all[each.key].id
  device_profile_id = local.devices[each.value].device_profile_id
  interfaces        = flatten([
    for map in local.devices[each.value].device_mapping : [
      for i in range(map.count) : {
        logical_device_port     = format("%d/%d", map.ld_panel, map.ld_first_port + i)
        physical_interface_name = format("%s%d", map.phy_prefix, map.phy_first_port + i)
      }
    ]
  ])
}

locals {
  im_sn_pairs = flatten([
    for group_index, group_name in local.device_group_list: [
      for device_label, device_key in local.devices[group_name].device_allocation: {
        device_key = device_key
        node_name  = device_label
        blueprint_id = apstra_datacenter_blueprint.all[index(local.blueprint_list, local.devices[group_name].blueprint)].id
        interface_map_id = apstra_interface_map.all[group_index].id
      }
    ]
  ])
}

# Assign interface maps to fabric roles to eliminate build errors so we can deploy
resource "apstra_datacenter_device_allocation" "all" {
  depends_on = [ 
    apstra_interface_map.all, 
    apstra_datacenter_blueprint.all
    ]
  for_each = { for index, i in local.im_sn_pairs: i.device_key => i }
  blueprint_id     = each.value.blueprint_id
  node_name        = each.value.node_name
  device_key       = each.value.device_key
  interface_map_id = each.value.interface_map_id
  deploy_mode      = "deploy"
}

