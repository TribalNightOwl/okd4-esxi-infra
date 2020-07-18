terraform {
  required_version = ">= 0.12"
  required_providers {
    esxi = {
      version = "~> 1.7"
    }
  }
}

resource "null_resource" "esxi_network" {
  # These triggers are just a workaround to be able to use variables in the destroy provisioner
  triggers = {
    netname = var.network_name
    switch  = var.vswitch
    host    = var.esxi_host
  }

  connection {
    host = self.triggers.host
  }

  provisioner "remote-exec" {
    inline = [
      "esxcli network vswitch standard portgroup add --portgroup-name=${var.network_name} --vswitch-name=${var.vswitch}",
      "esxcli network vswitch standard portgroup set -p ${var.network_name} --vlan-id ${var.vlan_id}",
    ]
  }

  provisioner "remote-exec" {
    when    = destroy
    inline = [
      "esxcli network vswitch standard portgroup remove --portgroup-name=${self.triggers.netname} --vswitch-name=${self.triggers.switch}",
    ]
  }
}

provider "esxi" {
  esxi_hostname      = var.esxi_host
  esxi_hostport      = "22"
  esxi_hostssl       = "443"
  esxi_username      = var.esxi_username
  esxi_password      = var.esxi_password
}

resource "esxi_guest" "okd4-bootstrap" {
  guest_name     = "okd4-bootstrap"
  numvcpus       = "4"
  memsize        = "16384"  # in Mb
  boot_disk_size = "120" # in Gb
  boot_disk_type = "thin"
  disk_store     = var.datastore
  guestos        = "fedora-64"
  power          = "off"
  virthwver      = "13"

  network_interfaces {
    mac_address     = "00:50:56:01:01:01"
    virtual_network = var.network_name
  }
  depends_on = [null_resource.esxi_network]
}

resource "esxi_guest" "okd4-machines" {
  for_each = {
    okd4-control-plane-1 = "00:50:56:01:01:02"
    okd4-control-plane-2 = "00:50:56:01:01:03"
    okd4-control-plane-3 = "00:50:56:01:01:04"
    okd4-compute-1 = "00:50:56:01:01:05"
    okd4-compute-2 = "00:50:56:01:01:06"
  }
  guest_name     = each.key
  numvcpus       = "4"
  memsize        = "16384"  # in Mb
  boot_disk_size = "120" # in Gb
  boot_disk_type = "thin"
  disk_store     = var.datastore
  guestos        = "fedora-64"
  power          = "off"
  virthwver      = "13"

  network_interfaces {
    mac_address     = each.value
    virtual_network = var.network_name
  }
  depends_on = [null_resource.esxi_network]
}

resource "esxi_guest" "okd4-services" {
  guest_name     = "okd4-services"
  numvcpus       = "4"
  memsize        = "4096"  # in Mb
  boot_disk_size = "100" # in Gb
  boot_disk_type = "thin"
  disk_store     = var.datastore
  guestos        = "centos-64"
  power          = "off"
  virthwver      = "13"

  network_interfaces {
    mac_address     = "00:50:56:01:01:07"
    virtual_network = var.network_name
  }
  depends_on = [null_resource.esxi_network]
}

resource "esxi_guest" "okd4-pfsense" {
  guest_name     = "okd4-pfsense"
  numvcpus       = "1"
  memsize        = "1024"  # in Mb
  boot_disk_size = "8" # in Gb
  boot_disk_type = "thin"
  disk_store     = var.datastore
  guestos        = "freebsd-64"
  power          = "off"
  virthwver      = "13"

  network_interfaces {
    mac_address     = "00:50:56:01:01:08"
    virtual_network = var.network_name
  }
  depends_on = [null_resource.esxi_network]
}
