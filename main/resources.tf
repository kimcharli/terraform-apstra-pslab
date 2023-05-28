locals {
  resources = yamldecode(file("${path.module}/config.yaml")).resource
}

resource "apstra_ipv4_pool" "all" {
  for_each = local.resources.ipv4_pool
  name = each.key
  subnets = [ for subnet in each.value: { network = subnet } ]
}

resource "apstra_asn_pool" "all" {
  for_each = local.resources.asn_pool
  name = each.key
  ranges = [ for range in each.value: { first = range.first, last = range.last} ]
}

