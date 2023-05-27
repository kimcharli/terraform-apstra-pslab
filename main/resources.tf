locals {
  local_resource = yamldecode(file("${path.module}/config.yaml")).resource
}


resource "apstra_ipv4_pool" "loop" {
    name = local.local_resource.ipv4_pool.terra-loop.name
    subnets = local.local_resource.ipv4_pool.terra-loop.subnets 
}

resource "apstra_ipv4_pool" "fabric" {
    name = local.local_resource.ipv4_pool.terra-fabric.name
    subnets = local.local_resource.ipv4_pool.terra-fabric.subnets
}

resource "apstra_asn_pool" "asn" {
    name = local.local_resource.asn.terra-asn.name
    ranges = local.local_resource.asn.terra-asn.ranges
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
}


# Assign ASN pools to fabric roles to eliminate build errors so we can deploy
resource "apstra_datacenter_resource_pool_allocation" "asn" {
  for_each     = local.asn_pools
  blueprint_id = apstra_datacenter_blueprint.all.0.id
  role         = each.key
  pool_ids     = each.value
}

# Assign IPv4 pools to fabric roles to eliminate build errors so we can deploy
resource "apstra_datacenter_resource_pool_allocation" "ipv4" {
  depends_on = [ apstra_datacenter_blueprint.all ]
  for_each     = local.ipv4_pools
  blueprint_id = apstra_datacenter_blueprint.all.0.id
  role         = each.key
  pool_ids     = each.value
}

