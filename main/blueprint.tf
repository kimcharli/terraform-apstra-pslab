locals {
  rack_types = yamldecode(file("${path.module}/config.yaml")).rack_type
  rack_list = [ for k, v in local.rack_types : k ]
}


resource "apstra_rack_type" "all" {
  for_each = { for i, name in local.rack_list: i => name }
  name                       = local.rack_types[each.value].name
  description                = local.rack_types[each.value].description
  fabric_connectivity_design = local.rack_types[each.value].fabric_connectivity_design
  leaf_switches = { // leaf switches are a map keyed by switch name, so
    leaf_switch = { // "leaf switch" on this line is the name used by links targeting this switch.
      # logical_device_id   = apstra_logical_device.server-leaf.id
      logical_device_id   = apstra_logical_device.all[index(local.device_group_list, local.rack_types[each.value].leaf_switches.0.logical_device)].id
      spine_link_count    = local.rack_types[each.value].leaf_switches.0.spine_link_count
      spine_link_speed    = local.rack_types[each.value].leaf_switches.0.spine_link_speed
      redundancy_protocol = local.rack_types[each.value].leaf_switches.0.redundancy_protocol
    }
  }
}


locals {
  templates = yamldecode(file("${path.module}/config.yaml")).template
  template_list = [ for k, v in local.templates : k ]
}


resource "apstra_template_rack_based" "all" {
  for_each = { for i, name in local.template_list: i => name }
  name                     = local.templates[each.value].name
  asn_allocation_scheme    = local.templates[each.value].asn_allocation_scheme
  overlay_control_protocol = local.templates[each.value].overlay_control_protocol
  spine = {
    logical_device_id = apstra_logical_device.all[index(local.device_group_list, local.templates[each.value].spine.logical_device)].id
    count = 2
  }
  rack_infos = {
    # for id, count in local.rack_id_and_count : id => { count = count }
    for label, count in local.templates[each.value].racks:
      apstra_rack_type.all[index(local.rack_list, label)].id => { count = count }
  }
}



locals {
  blueprint = yamldecode(file("${path.module}/config.yaml")).blueprint
  blueprint_list = [ for k, v in local.blueprint : k ]
}


resource "apstra_datacenter_blueprint" "all" {
  for_each = { for i, name in local.blueprint_list: i => name }
  name        = local.blueprint[each.value].name
  template_id = apstra_template_rack_based.all[index(local.template_list, local.blueprint[each.value].template_name)].id
}



# The only required field for deployment is blueprint_id, but we're ensuring
# sensible run order and setting a custom commit message.
resource "apstra_blueprint_deployment" "deploy" {
  blueprint_id = apstra_datacenter_blueprint.all.0.id

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


