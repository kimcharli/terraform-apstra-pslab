terraform {
  required_providers {
    apstra = {
        source = "Juniper/apstra"
        # terraform init --upgrade
        version = "0.14.1"
    }
  }
}

# # working example. The workspace setting should be set to local execution mode for on prem case
# terraform {
#   cloud {
#     organization = "kimcharli"

#     workspaces {
#       name = "test1-workspace"
#     }
#   }
# }

# # working example
# terraform {
#   backend "gcs" {
#     bucket  = "kimcharli-bucket-002"
#     prefix  = "terraform/state"
#   }
# }

# provider "apstra" {
#     url = "https://10.85.192.42"
#     tls_validation_disabled = true
# }

# encoded string: python3 -c 'import urllib.parse; print(urllib.parse.quote("zaq1@WSXcde3$RFV"))'
provider "apstra" {
    url = "https://terraform:zaq1%40WSXcde3%24RFV@10.85.192.50"
    tls_validation_disabled = true
}


