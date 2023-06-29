#### Routing Zone

locals {
  routing_zones = flatten([ 
    for bp_label, bp in local.blueprint : [
      for rz_label, rz in bp.routing_zones: {
        name = rz_label
        bp_label = bp_label
        blueprint_id = apstra_datacenter_blueprint.all[bp_label].id
        vlan_id = rz.vlan_id
        vni = rz.vni
        dhcp_servers = rz.dhcp_servers
        leaf_loopback_ips = rz.leaf_loopback_ips        
      }
    ]
  ])
  routing_zones_dict = {
    for rz in local.routing_zones : "${rz.bp_label}-${rz.name}" => rz
  }
}


# create routing zone
resource "apstra_datacenter_routing_zone" "all" {
  depends_on = [ apstra_blueprint_deployment.deploy ]
  for_each = local.routing_zones_dict
  name = each.value.name
  blueprint_id =  each.value.blueprint_id
  vlan_id = each.value.vlan_id
  vni = each.value.vni
  dhcp_servers = each.value.dhcp_servers  
}

# allocate leaf loopback pool on the routing zone
resource "apstra_datacenter_resource_pool_allocation" "vrf" {
  for_each = local.routing_zones_dict
  blueprint_id =  each.value.blueprint_id
  role         = "leaf_loopback_ips"
  pool_ids     = [ for x in each.value.leaf_loopback_ips : apstra_ipv4_pool.all[x].id ]
  routing_zone_id = apstra_datacenter_routing_zone.all[each.key].id
}


#### Virtual Network

locals {
  virtual_networks = flatten([ 
    for bp_label, bp in local.blueprint : [
      for rz_label, rz in bp.routing_zones: [
        for vn_label, vn in rz.vlans: {
          vn_key = "${bp_label}-${vn_label}"
          name = vn_label
          # bp_label = bp_label
          blueprint_id = apstra_datacenter_blueprint.all[bp_label].id
          routing_zone_id = apstra_datacenter_routing_zone.all["${bp_label}-${rz_label}"].id
          vlan_id = vn.vlan_id
          vni = vn.vni
        }
      ]
    ]
  ])
  virtual_networks_dict = {
    for vn in local.virtual_networks : vn.vn_key => vn
  }
}

# resource "apstra_datacenter_virtual_network" "all" {
#   for_each = local.virtual_networks_dict
#   name = each.value.name
#   blueprint_id = each.value.blueprint_id
#   routing_zone_id = each.value.routing_zone_id
#   type = each.value.type
#   vlan_id = each.value.vlan_id
#   vni = each.value.vni
#   bindings = {
#     "name" = {
      
#     }
#   }
  
# }

resource "apstra_blueprint_deployment" "vrf" {
  for_each = local.blueprint
  blueprint_id = apstra_datacenter_blueprint.all[each.key].id

  depends_on = [
    apstra_datacenter_resource_pool_allocation.vrf,
  ]

  comment      = "Commit RZ by Terraform {{.TerraformVersion}}, Apstra provider {{.ProviderVersion}}, User $USER."
}


