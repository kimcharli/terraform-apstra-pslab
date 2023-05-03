resource "apstra_configlet" "aosadmin-ssh-rsa" {
  name = "aosadmin-ssh-rsa"
  generators = [
    {
      config_style  = "junos"
      section       = "system"
      template_text = <<-EOT
        system {
            login {
                user aosadmin {
                    authentication {
                        ssh-rsa "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDPL78MoahulNonlvUSG4F0GHXRTp4lrFdynZO1ufdXHBSGc0SuZTiJAPbPGJidMxWpWoIHEVpp8x3u5jNMVoo4UCEiMrQc4Cqz5NlxCNM2Y5mn/LO7no3LijlMV8QW72eo79LZFjPwwnFeclvEaqCazZ7QCjpLA9dadLa4+dG9AgZQ9p6AsbY4iNIBVyvRZO1zrE2qOUBdeYy1nBMy8iDdquZGityhLBABEaXHi7TcLP5evCCQ/PkVWtmwO7V5d6fniFhWAlAFo7sKm25RTYffcA1wCnGFOGqbtzkYgW8LSZKe4DKtRmp/NrhoG59rqXf+y+zzZayQtIlbyML7Q9Ot ckim@ckim-mbp"; ## SECRET-DATA
                    }
                }
            }
        }
      EOT
    }
  ]
}