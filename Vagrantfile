# -*- mode: ruby -*-
# vi: set ft=ruby :

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
Vagrant.configure("2") do |config|
  boxes = [
#    { :name => "master-0", :box => "almalinux/8" },
    { :name => "haproxy",  :box => "package.box" },
    { :name => "master-0", :box => "package.box" },
    { :name => "master-1", :box => "package.box" },
    { :name => "master-2", :box => "package.box" }
 
  ]

  last_octet = 9
  boxes.each do |opts|
    config.vm.define opts[:name] do |config|
      config.vm.box = opts[:box]
      config.vm.hostname = opts[:name]
      config.vm.network "private_network", ip: "10.10.10.#{last_octet}"
      last_octet += 1

      config.vm.provider "virtualbox" do |vb|
        vb.memory = "3072"
        vb.cpus = 2
        vb.linked_clone = true
      end

      #config.vm.provision "Change default route", type: "shell", inline: <<-SHELL
      #  "ip route add default 10.10.10.1 via enp0s8"
      #SHELL
      
    end
  end
end

