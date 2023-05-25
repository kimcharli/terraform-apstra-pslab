terraform {
  required_providers {
    apstra = {
        source = "Juniper/apstra"
    }
  }
}

# # encoded string: python3 -c 'import urllib.parse; print(urllib.parse.quote("zaq1@WSXcde3$RFV"))'
# provider "apstra" {
#     url = "https://terraform:zaq1%40WSXcde3%24RFV@10.85.192.50"
#     tls_validation_disabled = true
# }



