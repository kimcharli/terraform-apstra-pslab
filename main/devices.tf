
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
  initial_interface_map_id = apstra_interface_map.all[each.value.interface_map].id
  deploy_mode      = "deploy"
}


locals {
  device_label_id = {
    for device in apstra_datacenter_device_allocation.all : device.node_name => device.node_id
  }
}

#### Generic System allocation
locals {
  generic_system_list = flatten([
    for bp_label, bp in local.blueprint : [
      for gs_label, gs in bp.generic_systems : {
        blueprint_id = apstra_datacenter_blueprint.all[bp_label].id
        name = gs_label
        hostname = gs.hostname
        tags = gs.tags
        links = [
          for link in gs.links: {
            tags = link.tags
            lag_mode = link.lag_mode
            target_switch_id = local.device_label_id[link.target_switch]
            target_switch_if_name = link.target_switch_if_name
            target_switch_if_transform_id = link.target_switch_if_transform_id
            group_label = link.group_label
          }
        ]
      }
    ]
  ])
  generic_system_dict = {
    for gs in local.generic_system_list : gs.name => gs
  }

}

resource "apstra_datacenter_generic_system" "all" {
  for_each = local.generic_system_dict
  blueprint_id = each.value.blueprint_id
  name = each.value.name
  hostname = each.value.hostname
  tags = each.value.tags
  links = each.value.links
}
