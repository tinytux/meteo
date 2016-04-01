# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|

  ENV['VAGRANT_DEFAULT_PROVIDER'] = 'docker'
  # Every Vagrant virtual environment requires a box to build off of.
  # config.vm.box = "base"

  config.vm.provider "docker" do |node|
    node.name = "meteo"
    node.build_dir = "."
    node.has_ssh = true
  end
  config.ssh.port = 22

  # Run the provisioning script
  config.vm.provision :shell, path: "./scripts/setup.sh"
  config.vm.provision "shell", inline: <<-SHELL
    sudo /usr/sbin/cron &
SHELL
end

