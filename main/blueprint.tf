#### rack
locals {
  rack_types = yamldecode(file("${path.module}/config.yaml")).rack_type
}


resource "apstra_rack_type" "all" {
  for_each = local.rack_types
  name                       = each.value.name
  description                = each.value.description
  fabric_connectivity_design = each.value.fabric_connectivity_design
  leaf_switches = { // leaf switches are a map keyed by switch name, so
    leaf_switch = { // "leaf switch" on this line is the name used by links targeting this switch.
      logical_device_id   = apstra_logical_device.all[each.value.leaf_switches.0.logical_device].id
      spine_link_count    = each.value.leaf_switches.0.spine_link_count
      spine_link_speed    = each.value.leaf_switches.0.spine_link_speed
      redundancy_protocol = each.value.leaf_switches.0.redundancy_protocol
    }
  }
}


#### template

locals {
  templates = yamldecode(file("${path.module}/config.yaml")).template
}

resource "apstra_template_rack_based" "all" {
  for_each = local.templates
  name                     = each.key
  asn_allocation_scheme    = each.value.asn_allocation_scheme
  overlay_control_protocol = each.value.overlay_control_protocol
  spine = {
    logical_device_id = apstra_logical_device.all[each.value.spine.logical_device].id
    count = 2
  }
  rack_infos = {
    for label, count in each.value.racks:
      apstra_rack_type.all[label].id => { count = count }
  }
}


#### blueprint

locals {
  blueprint = yamldecode(file("${path.module}/config.yaml")).blueprint
}


resource "apstra_datacenter_blueprint" "all" {
  for_each = local.blueprint
  name        = each.key
  template_id = apstra_template_rack_based.all[each.value.template_name].id
}


#### blueprint pool allocation

# Assign ASN pools to fabric roles to eliminate build errors so we can deploy
locals {
  asn_pools_list = flatten([
    for bp_label, bp in local.blueprint : [
      for pool_label, pools in bp.asn_pools : {
        bp_label = bp_label
        pool_name = pool_label
        pools = pools
        }
    ]
  ])
  asn_pool_dict = {
    for pool in local.asn_pools_list : "${pool.bp_label}-${pool.pool_name}" => pool
  }
}

resource "apstra_datacenter_resource_pool_allocation" "asn" {
  for_each     = local.asn_pool_dict
  blueprint_id = apstra_datacenter_blueprint.all[each.value.bp_label].id
  role         = each.value.pool_name
  pool_ids     = [ for x in each.value.pools : apstra_asn_pool.all[x].id ]
}


# Assign IPv4 pools to fabric roles to eliminate build errors so we can deploy
locals {
  ipv4_pools_list = flatten([
    for bp_label, bp in local.blueprint : [
      for pool_label, pools in bp.ipv4_pools : {
        bp_label = bp_label
        pool_name = pool_label
        pools = pools
        }
    ]
  ])
  ipv4_pool_dict = {
    for pool in local.ipv4_pools_list : "${pool.bp_label}-${pool.pool_name}" => pool
  }
}

resource "apstra_datacenter_resource_pool_allocation" "ipv4" {
  depends_on = [ apstra_datacenter_blueprint.all ]
  for_each     = local.ipv4_pool_dict
  blueprint_id = apstra_datacenter_blueprint.all[each.value.bp_label].id
  role         = each.value.pool_name
  pool_ids     = [ for x in each.value.pools : apstra_ipv4_pool.all[x].id ]
}


# property_set
locals {
  bp_property_set = flatten([
    for bp_label, bp in local.blueprint : [
      for ps_label, ps in bp.property_sets : {
        resource_key = "${bp_label}-${ps_label}"
        bp_id = apstra_datacenter_blueprint.all[bp_label].id
        id = apstra_property_set.all[ps_label].id
        keys = ps
        }
    ]
  ])
  bp_property_set_dict = {
    for ps in local.bp_property_set : ps.resource_key => ps
  }
}

resource "apstra_datacenter_property_set" "all" {
  for_each     = local.bp_property_set_dict
  blueprint_id = each.value.bp_id
  id = each.value.id
  keys = each.value.keys
}



# The only required field for deployment is blueprint_id, but we're ensuring
# sensible run order and setting a custom commit message.
resource "apstra_blueprint_deployment" "deploy" {
  for_each = local.blueprint
  blueprint_id = apstra_datacenter_blueprint.all[each.key].id

  #ensure that deployment doesn't run before build errors are resolved
  depends_on = [
    apstra_datacenter_device_allocation.all,
    apstra_datacenter_resource_pool_allocation.asn,
    apstra_datacenter_resource_pool_allocation.ipv4,
  ]

  # Version is replaced using `text/template` method. Only predefined values
  # may be replaced with this syntax. USER is replaced using values from the
  # environment. Any environment variable may be specified this way.
  comment      = "Deployment by Terraform {{.TerraformVersion}}, Apstra provider {{.ProviderVersion}}, User $USER."
}




