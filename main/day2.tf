#### rack

locals {
#   blueprint = yamldecode(file("${path.module}/config.yaml")).blueprint  # from blurprint
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



resource "apstra_datacenter_routing_zone" "all" {
  depends_on = [ apstra_blueprint_deployment.deploy ]
  for_each = local.routing_zones_dict
  name = each.value.name
  blueprint_id =  each.value.blueprint_id
  vlan_id = each.value.vlan_id
  vni = each.value.vni
  dhcp_servers = each.value.dhcp_servers  
}

resource "apstra_datacenter_resource_pool_allocation" "vrf" {
  for_each = local.routing_zones_dict
  blueprint_id =  each.value.blueprint_id
  role         = "leaf_loopback_ips"
  pool_ids     = [ for x in each.value.leaf_loopback_ips : apstra_ipv4_pool.all[x].id ]
  routing_zone_id = apstra_datacenter_routing_zone.all[each.key].id
}





