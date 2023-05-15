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


# ASN pools, IPv4 pools and switch devices will be allocated using looping
# resources. These three `local` maps are what we'll loop over.
locals {
  asn_pools = {
    spine_asns = [apstra_asn_pool.asn.id]
    leaf_asns  = [apstra_asn_pool.asn.id]
  }
  ipv4_pools = {
    spine_loopback_ips  = [apstra_ipv4_pool.loop.id]
    leaf_loopback_ips   = [apstra_ipv4_pool.loop.id]
    spine_leaf_link_ips = [apstra_ipv4_pool.fabric.id]
  }
  switch_map = {
    spines = {
      switches = [ "spine1", "spine2" ]
      interface_map_id = apstra_interface_map.spine.id
    },
    border_leafs = {
      switches = [ "pslab_border_001_leaf1", "pslab_border_001_leaf2"]
      interface_map_id = apstra_interface_map.border-leaf.id
    },
    server_leafs = {
      switches = [ "pslab_server_001_leaf1", "pslab_server_001_leaf2"]
      interface_map_id = apstra_interface_map.server-leaf.id
    },
  }
}

# Assign interface maps to fabric roles to eliminate build errors so we can deploy

resource "apstra_datacenter_device_allocation" "spines" {
  depends_on = [ apstra_datacenter_blueprint.blueprint-pslab ]
  for_each         = toset(local.switch_map.spines.switches)
  blueprint_id     = apstra_datacenter_blueprint.blueprint-pslab.id
  node_name        = each.key
  interface_map_id = local.switch_map.spines.interface_map_id
}

resource "apstra_datacenter_device_allocation" "border-leafs" {
  depends_on = [ apstra_datacenter_blueprint.blueprint-pslab ]
  for_each         = toset(local.switch_map.border_leafs.switches)
  blueprint_id     = apstra_datacenter_blueprint.blueprint-pslab.id
  node_name        = each.key
  interface_map_id = local.switch_map.border_leafs.interface_map_id
}

resource "apstra_datacenter_device_allocation" "server-leafs" {
  depends_on = [ apstra_datacenter_blueprint.blueprint-pslab ]
  for_each         = toset(local.switch_map.server_leafs.switches)
  blueprint_id     = apstra_datacenter_blueprint.blueprint-pslab.id
  node_name        = each.key
  interface_map_id = local.switch_map.server_leafs.interface_map_id
}

