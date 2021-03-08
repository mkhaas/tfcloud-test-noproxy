

module "create_cluster_a" {
  source = "./modules/iks/"

  app_name = "test"
  cluster_name = "a"

  dns_servers = var.dns_servers
  ntp_servers = var.ntp_servers

  vcenter_target = var.vcenter_target
  vcenter_cluster = var.vcenter_cluster
  vcenter_datastore = var.vcenter_datastore
  vcenter_network = var.vcenter_network
  vcenter_passphrase = var.vcenter_passphrase

  ip_pool = var.ip_pool

  ssh_user = var.ssh_user
  ssh_keys = var.ssh_keys
}

output "cluster_info" {
  value = module.create_cluster_a.cluster_info
}
