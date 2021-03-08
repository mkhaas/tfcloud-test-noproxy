############################################################
# REQUIRED PROVIDERS
############################################################
terraform {
  required_providers {
    intersight = {
      source  = "CiscoDevNet/intersight"
      version = "== 1.0.0"
    }
  }
}


#############################
# GET ORGANIZATION MOID
#############################
data "intersight_organization_organization" "organization" {
  name = var.org
}

#############################
# GET AVAILABLE K8S VERSIONS
#############################
data "intersight_kubernetes_version" "version" {
  kubernetes_version = join("", ["v", var.k8s_version])
}

#############################
# CREATE K8S VERSION POLICY
#############################
resource "intersight_kubernetes_version_policy" "k8s_version" {

  name = "${var.app_name}_${var.cluster_name}_k8s_version"

  nr_version {
    object_type = "kubernetes.Version"
    moid        = data.intersight_kubernetes_version.version.moid
  }

  organization {
    object_type = "organization.Organization"
    moid        = data.intersight_organization_organization.organization.moid
  }
}

#############################
# CREATE K8S SYS CONFIG POLICY
#############################
resource "intersight_kubernetes_sys_config_policy" "k8s_sysconfig" {

  name = "${var.app_name}_${var.cluster_name}_k8s_sysconfig"

  dns_servers = var.dns_servers

  ntp_servers = var.ntp_servers
  timezone = var.timezone

  organization {
    object_type = "organization.Organization"
    moid        = data.intersight_organization_organization.organization.moid
  }
}

#############################
# CREATE K8S NETWORK POLICY
#############################
resource "intersight_kubernetes_network_policy" "k8s_network" {

  name = "${var.app_name}_${var.cluster_name}_k8s_network"

  pod_network_cidr = var.pod_network_cidr
  service_cidr = var.service_cidr

  organization {
    object_type = "organization.Organization"
    moid        = data.intersight_organization_organization.organization.moid
  }
}

#############################
# CREATE K8S NODE TYPE POLICY
#############################
resource "intersight_kubernetes_virtual_machine_instance_type" "k8s_nodetype" {

  name = "${var.app_name}_${var.cluster_name}_k8s_nodetype"

  cpu = 4
#  memory = 4096
  disk_size = var.disk_size

  organization {
    object_type = "organization.Organization"
    moid        = data.intersight_organization_organization.organization.moid
  }
}

#############################
# GET VCENTER MOID
#############################
data "intersight_asset_target" "infra_target" {
  name = var.vcenter_target
}

#############################
# CREATE K8S INFRA PROVIDER
#############################
resource "intersight_kubernetes_virtual_machine_infrastructure_provider" "k8s_infraprovider" {

  name = "${var.app_name}_${var.cluster_name}_k8s_infraprovider"

  infra_config {
    object_type = "kubernetes.EsxiVirtualMachineInfraConfig"
    interfaces  = var.vcenter_network
    additional_properties = jsonencode({
      Datastore    = var.vcenter_datastore
      Cluster      = var.vcenter_cluster
      Passphrase   = var.vcenter_passphrase
    })
  }

  instance_type {
      object_type = "kubernetes.VirtualMachineInstanceType"
      moid = intersight_kubernetes_virtual_machine_instance_type.k8s_nodetype.moid
  }

  target {
    object_type = "asset.DeviceRegistration"
    moid = data.intersight_asset_target.infra_target.registered_device[0].moid

  }

  organization {
    object_type = "organization.Organization"
    moid        = data.intersight_organization_organization.organization.moid
  }

  provisioner "local-exec" {
    command = "ls"
  }
}

#############################
# CREATE MASTER NODE GROUP FOR CLUSTER
#############################
resource "intersight_kubernetes_node_group_profile" "k8s_mastergroup" {

  name = "${var.app_name}_${var.cluster_name}_k8s_mastergroup"

  node_type = "Master"

  desiredsize = var.master_count

  kubernetes_version {
    moid = intersight_kubernetes_version_policy.k8s_version.moid
    object_type = "kubernetes.VersionPolicy"
  }

  infra_provider {
    moid = intersight_kubernetes_virtual_machine_infrastructure_provider.k8s_infraprovider.moid
    object_type = "kubernetes.VirtualMachineInfrastructureProvider"
  }

  ip_pools {
    moid = var.ip_pool
    object_type = "ippool.Pool"
  }

  cluster_profile {
    object_type = "kubernetes.ClusterProfile"
    moid = intersight_kubernetes_cluster_profile.k8s_cluster.id
  }
}

#############################
# CREATE WORKER NODE GROUP FOR CLUSTER A
#############################
resource "intersight_kubernetes_node_group_profile" "k8s_workergroup" {

  name = "${var.app_name}_${var.cluster_name}_k8s_workergroup"

  node_type = "Worker"

  desiredsize = var.worker_count

  kubernetes_version {
    moid = intersight_kubernetes_version_policy.k8s_version.moid
    object_type = "kubernetes.VersionPolicy"
  }

  infra_provider {
    moid = intersight_kubernetes_virtual_machine_infrastructure_provider.k8s_infraprovider.moid
    object_type = "kubernetes.VirtualMachineInfrastructureProvider"
  }

  ip_pools {
    moid = var.ip_pool
    object_type = "ippool.Pool"
  }

  cluster_profile {
    object_type = "kubernetes.ClusterProfile"
    moid = intersight_kubernetes_cluster_profile.k8s_cluster.moid
  }
}

############################################################
# CREATE K8S PROFILE
############################################################
resource "intersight_kubernetes_cluster_profile" "k8s_cluster" {

  name = "${var.app_name}_${var.cluster_name}_k8s_cluster"

  action = "Deploy"

  cluster_ip_pools {
    moid = var.ip_pool
    object_type = "ippool.Pool"
  }

  management_config {
    load_balancer_count = var.loadbalancer_count
    ssh_user = var.ssh_user
    ssh_keys = var.ssh_keys
  }

  sys_config {
    moid = intersight_kubernetes_sys_config_policy.k8s_sysconfig.moid
    object_type = "kubernetes.SysConfigPolicy"
  }

  net_config {
    moid = intersight_kubernetes_network_policy.k8s_network.moid
    object_type = "kubernetes.NetworkPolicy"
  }

  organization {
    object_type = "organization.Organization"
    moid        = data.intersight_organization_organization.organization.moid
  }
}

############################################################
# WAIT FOR KUBECONFIG TO BE CREATED
############################################################
resource "time_sleep" "sleep_after_cluster_creation" {
  depends_on = [intersight_kubernetes_cluster_profile.k8s_cluster]

  create_duration = "30s"
}

############################################################
# GET CLUSTER INFORMATION
############################################################
data "intersight_kubernetes_cluster_profile" "output" {
  depends_on = [time_sleep.sleep_after_cluster_creation]
  name = "${var.app_name}_${var.cluster_name}_k8s_cluster"
}

############################################################
# EXTRACT KUBECONFIG
############################################################
resource "local_file" "buffer" {
  depends_on = [data.intersight_kubernetes_cluster_profile.output]
    content     = jsonencode(data.intersight_kubernetes_cluster_profile.output)
    filename = "${path.module}/buffer.json"
}

resource "null_resource" "extract_step" {
  depends_on = [local_file.buffer]
  provisioner "local-exec" {

    command = "cat ${path.module}/buffer.json | jq '.kube_config[0].kube_config' > ${path.module}/kubeconfig.json"
  }
}

data "local_file" "kubeconfig" {
  depends_on = [null_resource.extract_step]
  filename = "${path.module}/kubeconfig.json"
}

############################################################
# DEFINE OUTPUT
############################################################
output "cluster_info" {
  value = data.local_file.kubeconfig.content
}
