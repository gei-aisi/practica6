# -*- mode: ruby -*-
# vi: set ft=ruby :
require_relative 'provisioning/vbox.rb'
VBoxUtils.check_version('7.2.4')
Vagrant.require_version ">= 2.4.9"

STUDEN_PREFIX = "X"
BOX_NAME = "Y"

# Hostnames for master and worker nodes
MASTER_HOSTNAME = "#{STUDEN_PREFIX}-master"
WORKER_HOSTNAME = "#{STUDEN_PREFIX}-worker"

# Cluster settings
MASTER_IP = "192.168.56.10"
NUM_WORKERS = 3
MASTER_CORES = 1
WORKER_CORES = 1
MASTER_MEMORY = 2048
WORKER_MEMORY = 2048
MASTER_NUM_DISKS=3
MASTER_DISK_SIZE='10GB'
WORKER_NUM_DISKS=3
WORKER_DISK_SIZE='20GB'

require 'ipaddr'
CLUSTER_IP_ADDR = IPAddr.new MASTER_IP
CLUSTER_DOMAIN = "cluster.local"

Vagrant.configure("2") do |config|
  config.vm.box = BOX_NAME
  config.vm.box_check_update = false

  # Configure hostmanager plugin
  config.hostmanager.enabled = true
  config.hostmanager.manage_host = true
  config.hostmanager.manage_guest = true

  # Master node
  config.vm.define "master", primary: true do |master|
    master.vm.hostname = MASTER_HOSTNAME
    master.vm.network "private_network", ip: MASTER_IP
    master.hostmanager.aliases = ["#{MASTER_HOSTNAME}.#{CLUSTER_DOMAIN}"]

    for i in 1..MASTER_NUM_DISKS do
        master.vm.disk :disk, size: MASTER_DISK_SIZE, primary: false, name: "disk#{i}"
    end
    
    master.vm.provider "virtualbox" do |vb|
        vb.name = "AISI-P6-#{master.vm.hostname}"
        vb.cpus = MASTER_CORES
        vb.memory = MASTER_MEMORY
        vb.gui = false
        vb.customize ["modifyvm", :id, "--graphicscontroller", "vmsvga"]
    end

    # Install ansible on the master node
    master.vm.provision "ansible", type: "ansible_local", run: "never" do |ansible|
      ansible.install = "true"
      ansible.install_mode = "pip3"
      ansible.playbook = "provisioning/playbook.yml"
      ansible.inventory_path = "ansible.inventory"
      ansible.limit = "all"
      ansible.extra_vars = {
        master_hostname: MASTER_HOSTNAME,
        master_ip: MASTER_IP,
        worker_cores: WORKER_CORES,
        num_workers: NUM_WORKERS,
      }
    end
  end
  
  # Worker nodes
  (1..NUM_WORKERS).each do |i|
    config.vm.define "worker#{i}" do |worker|
      current_worker_hostname = "#{WORKER_HOSTNAME}#{i}"
      worker.vm.hostname = current_worker_hostname
      CLUSTER_IP_ADDR = CLUSTER_IP_ADDR.succ
      worker.vm.network "private_network", ip: CLUSTER_IP_ADDR.to_s
      worker.hostmanager.aliases = ["#{current_worker_hostname}.#{CLUSTER_DOMAIN}"]
      
      for i in 1..WORKER_NUM_DISKS do
            worker.vm.disk :disk, size: WORKER_DISK_SIZE, primary: false, name: "disk#{i}"
      end
        
      worker.vm.provider "virtualbox" do |vb|
	      vb.name = "AISI-P6-#{worker.vm.hostname}"
        vb.cpus = WORKER_CORES
        vb.memory = WORKER_MEMORY
	      vb.gui = false
	      vb.customize ["modifyvm", :id, "--graphicscontroller", "vmsvga"]
      end
    end
  end
  
  # Global provisioning bash script
  config.vm.provision "global", type: "shell", run: "always", path: "provisioning/bootstrap.sh"  do |script|
      script.args = [MASTER_HOSTNAME]
  end
end
