resource "apstra_ipv4_pool" "loop" {
    name = "pslab-loop"
    subnets = [
      { network = "10.0.0.0/24" }
    ]
}

resource "apstra_ipv4_pool" "fabric" {
    name = "pslab-fabric"
    subnets = [
      { network = "10.0.1.0/24" }
    ] 
}

resource "apstra_asn_pool" "asn" {
    name = "pslab-asn"
    ranges = [
      {
        first = 4200000000
        last = 4200001000
      }
    ]
}

# Assign ASN pools to fabric roles to eliminate build errors so we can deploy
resource "apstra_datacenter_resource_pool_allocation" "asn" {
  for_each     = local.asn_pools
  blueprint_id = apstra_datacenter_blueprint.blueprint-pslab.id
  role         = each.key
  pool_ids     = each.value
}

# Assign IPv4 pools to fabric roles to eliminate build errors so we can deploy
resource "apstra_datacenter_resource_pool_allocation" "ipv4" {
  for_each     = local.ipv4_pools
  blueprint_id = apstra_datacenter_blueprint.blueprint-pslab.id
  role         = each.key
  pool_ids     = each.value
}

