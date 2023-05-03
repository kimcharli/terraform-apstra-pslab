
resource "apstra_rack_type" "server-rack" {
  name                       = "pslab-server"
  description                = "server rack"
  fabric_connectivity_design = "l3clos"
  leaf_switches = { // leaf switches are a map keyed by switch name, so
    leaf_switch = { // "leaf switch" on this line is the name used by links targeting this switch.
      logical_device_id   = apstra_logical_device.server-leaf.id
      spine_link_count    = 1
      spine_link_speed    = "40G"
      redundancy_protocol = "esi"
    }
  }
}


resource "apstra_rack_type" "border-rack" {
  name                       = "pslab-border"
  description                = "border rack"
  fabric_connectivity_design = "l3clos"
  leaf_switches = { // leaf switches are a map keyed by switch name, so
    leaf_switch = { // "leaf switch" on this line is the name used by links targeting this switch.
      logical_device_id   = apstra_logical_device.border-leaf.id
      spine_link_count    = 1
      spine_link_speed    = "40G"
      redundancy_protocol = "esi"
    }
  }
}

locals {
  rack_id_and_count = [
    {
        id = apstra_rack_type.border-rack.id
        count = 1
    },
    {
        id = apstra_rack_type.server-rack.id
        count = 1
    },
  ]
}


resource "apstra_template_rack_based" "template-pslab" {
  name                     = "pslab-template"
  asn_allocation_scheme    = "unique"
  overlay_control_protocol = "evpn"
  spine = {
    logical_device_id = apstra_logical_device.spine.id
    count = 2
  }
  rack_infos = {
    # for id, count in local.rack_id_and_count : id => { count = count }
    for rack_type in local.rack_id_and_count: rack_type.id => { count = rack_type.count }
  }
}




resource "apstra_datacenter_blueprint" "blueprint-pslab" {
  name        = "pslab"
  template_id = apstra_template_rack_based.template-pslab.id
}



# The only required field for deployment is blueprint_id, but we're ensuring
# sensible run order and setting a custom commit message.
resource "apstra_blueprint_deployment" "deploy" {
  blueprint_id = apstra_datacenter_blueprint.blueprint-pslab.id

  #ensure that deployment doesn't run before build errors are resolved
  depends_on = [
    apstra_datacenter_device_allocation.spines,
    apstra_datacenter_device_allocation.border-leafs,
    apstra_datacenter_device_allocation.server-leafs,
    apstra_datacenter_resource_pool_allocation.asn,
    apstra_datacenter_resource_pool_allocation.ipv4,
  ]

  # Version is replaced using `text/template` method. Only predefined values
  # may be replaced with this syntax. USER is replaced using values from the
  # environment. Any environment variable may be specified this way.
  comment      = "Deployment by Terraform {{.TerraformVersion}}, Apstra provider {{.ProviderVersion}}, User $USER."
}
