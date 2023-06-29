#### rack

locals {
  global_property_set = yamldecode(file("${path.module}/config.yaml")).property_sets
}

resource "apstra_property_set" "all" {
    for_each = local.global_property_set
    name = each.key
    data = jsonencode(each.value)
}