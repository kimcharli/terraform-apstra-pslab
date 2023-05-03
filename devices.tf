#### spine
resource "apstra_logical_device" "spine" {
  name = "pslab-spine"
  panels = [
    {
      rows = 2
      columns = 18
      port_groups = [
        {
          port_count = 36
          port_speed = "40G"
          port_roles = ["leaf", "generic"]
        },
      ]
    }
  ]
}

locals {
  spine_device_profile ="Juniper_QFX10002-36Q_Junos"
  spine_map = [
    { // map logical 1/1 - 1/32 to physical et-0/0/0 - et-0/0/31
      ld_panel       = 1
      ld_first_port  = 1
      phy_prefix     = "et-0/0/"
      phy_first_port = 0
      count          = 36
    },
  ]
  spine_interfaces = [
    for map in local.spine_map : [
      for i in range(map.count) : {
        logical_device_port     = format("%d/%d", map.ld_panel, map.ld_first_port + i)
        physical_interface_name = format("%s%d", map.phy_prefix, map.phy_first_port + i)
      }
    ]
  ]
}

resource "apstra_interface_map" "spine" {
  name              = "pslab-spine"
  logical_device_id = apstra_logical_device.spine.id
  device_profile_id = local.spine_device_profile
  interfaces        = flatten([local.spine_interfaces])
}


#### border leaf
resource "apstra_logical_device" "border-leaf" {
  name = "pslab-border-leaf"
  panels = [
    {
      rows = 2
      columns = 28
      port_groups = [
        {
          port_count = 24
          port_speed = "10G"
          port_roles = ["access", "generic"]
        },
        {
          port_count = 24
          port_speed = "25G"
          port_roles = ["access", "generic"]
        },
        {
          port_count = 8
          port_speed = "40G"
          port_roles = ["spine", "generic"]
        },
      ]
    }
  ]
}

locals {
  border_leaf_device_profile = "Juniper_QFX5120-48Y_Junos"
  border_map = [
    { // map logical 1/1 - 1/24 to physical xe-0/0/0 - xe-0/0/23
      ld_panel       = 1
      ld_first_port  = 1
      phy_prefix     = "xe-0/0/"
      phy_first_port = 0
      count          = 24
    },
    { // map logical 1/25 - 1/56 to physical et-0/0/24 - xe-0/0/55
      ld_panel       = 1
      ld_first_port  = 25
      phy_prefix     = "et-0/0/"
      phy_first_port = 24
      count          = 32
    },
  ]
  border_interfaces = [
    for map in local.border_map : [
      for i in range(map.count) : {
        logical_device_port     = format("%d/%d", map.ld_panel, map.ld_first_port + i)
        physical_interface_name = format("%s%d", map.phy_prefix, map.phy_first_port + i)
      }
    ]
  ]
}

resource "apstra_interface_map" "border-leaf" {
  name              = "pslab-border"
  logical_device_id = apstra_logical_device.border-leaf.id
  device_profile_id = local.border_leaf_device_profile
  interfaces        = flatten([local.border_interfaces])
}


#### server leaf

resource "apstra_logical_device" "server-leaf" {
  name = "pslab-server-leaf"
  panels = [
    {
      rows = 2
      columns = 27
      port_groups = [
        {
          port_count = 48
          port_speed = "10G"
          port_roles = ["access", "generic"]
        },
        {
          port_count = 6
          port_speed = "40G"
          port_roles = ["spine", "generic"]
        },
      ]
    }
  ]
}

locals {
  server_leaf_device_profile = "Juniper_QFX5100-48S_Junos"
  server_map = [
    { // map logical 1/1 - 1/48 to physical xe-0/0/0 - xe-0/0/47
      ld_panel       = 1
      ld_first_port  = 1
      phy_prefix     = "xe-0/0/"
      phy_first_port = 0
      count          = 48
    },
    { // map logical 1/49 - 1/56 to physical et-0/0/48 - xe-0/0/53
      ld_panel       = 1
      ld_first_port  = 49
      phy_prefix     = "et-0/0/"
      phy_first_port = 48
      count          = 6
    },
  ]
  server_interfaces = [
    for map in local.server_map : [
      for i in range(map.count) : {
        logical_device_port     = format("%d/%d", map.ld_panel, map.ld_first_port + i)
        physical_interface_name = format("%s%d", map.phy_prefix, map.phy_first_port + i)
      }
    ]
  ]
}

resource "apstra_interface_map" "server-leaf" {
  name              = "pslab-server-leaf"
  logical_device_id = apstra_logical_device.server-leaf.id
  device_profile_id = local.server_leaf_device_profile
  interfaces        = flatten([local.server_interfaces])
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

