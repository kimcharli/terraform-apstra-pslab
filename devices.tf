locals {
  config = yamldecode(file("${path.module}/config.yaml"))
}


#### spine
resource "apstra_logical_device" "spine" {
  name = local.config.logical_device.spine.name
  panels = local.config.logical_device.spine.panels
}

resource "apstra_interface_map" "spine" {
  name              = local.config.logical_device.spine.name
  logical_device_id = apstra_logical_device.spine.id
  device_profile_id = local.config.logical_device.spine.device_profile_id
  interfaces        = flatten([
    for map in local.config.logical_device.spine.device_mapping : [
      for i in range(map.count) : {
        logical_device_port     = format("%d/%d", map.ld_panel, map.ld_first_port + i)
        physical_interface_name = format("%s%d", map.phy_prefix, map.phy_first_port + i)
      }
    ]
  ])
}


#### border leaf
resource "apstra_logical_device" "border-leaf" {
  name = local.config.logical_device.border-leaf.name
  panels = local.config.logical_device.border-leaf.panels
}

resource "apstra_interface_map" "border-leaf" {
  name              = local.config.logical_device.border-leaf.name
  logical_device_id = apstra_logical_device.border-leaf.id
  device_profile_id = local.config.logical_device.border-leaf.device_profile_id
  interfaces        = flatten([
    for map in local.config.logical_device.border-leaf.device_mapping: [
      for i in range(map.count) : {
        logical_device_port     = format("%d/%d", map.ld_panel, map.ld_first_port + i)
        physical_interface_name = format("%s%d", map.phy_prefix, map.phy_first_port + i)
      }
    ]    
  ])
}


#### server leaf

resource "apstra_logical_device" "server-leaf" {
  name = local.config.logical_device.server-leaf.name
  panels = local.config.logical_device.server-leaf.panels
}

resource "apstra_interface_map" "server-leaf" {
  name              = local.config.logical_device.server-leaf.name
  logical_device_id = apstra_logical_device.server-leaf.id
  device_profile_id = local.config.logical_device.server-leaf.device_profile_id
  interfaces        = flatten([
    for map in local.config.logical_device.server-leaf.device_mapping: [
      for i in range(map.count) : {
        logical_device_port     = format("%d/%d", map.ld_panel, map.ld_first_port + i)
        physical_interface_name = format("%s%d", map.phy_prefix, map.phy_first_port + i)
      }
    ]
  ])
}


# Assign interface maps to fabric roles to eliminate build errors so we can deploy

resource "apstra_datacenter_device_allocation" "spines" {
  depends_on = [ apstra_datacenter_blueprint.blueprint-terra ]
  for_each         = local.config.logical_device.spine.device_allocation
  blueprint_id     = apstra_datacenter_blueprint.blueprint-terra.id
  node_name        = each.key
  device_key       = each.value
  interface_map_id = apstra_interface_map.spine.id
  deploy_mode      = "deploy"
}

resource "apstra_datacenter_device_allocation" "border-leafs" {
  depends_on = [ apstra_datacenter_blueprint.blueprint-terra ]
  for_each         = local.config.logical_device.border-leaf.device_allocation
  blueprint_id     = apstra_datacenter_blueprint.blueprint-terra.id
  node_name        = each.key
  device_key       = each.value
  interface_map_id = apstra_interface_map.border-leaf.id
  deploy_mode      = "deploy"
}

resource "apstra_datacenter_device_allocation" "server-leafs" {
  depends_on = [ apstra_datacenter_blueprint.blueprint-terra ]
  for_each         = local.config.logical_device.server-leaf.device_allocation
  blueprint_id     = apstra_datacenter_blueprint.blueprint-terra.id
  node_name        = each.key
  device_key       = each.value
  interface_map_id = apstra_interface_map.server-leaf.id
  deploy_mode      = "deploy"
}

