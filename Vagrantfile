Vagrant.configure("2") do |config|
  config.vm.synced_folder ".", "/vagrant"
  
  # Конфигурация для Debian
  config.vm.define "debian" do |debian|
    debian.vm.box = "debian/bullseye64"
    debian.vm.provider "virtualbox" do |vb|
      vb.memory = "2048"
      vb.cpus = 2
    end
    
    debian.vm.provision "shell", inline: <<-SHELL
      apt-get update
      apt-get install -y python3-pip git
      pip3 install ansible==5.10.0
    SHELL
    
    debian.vm.provision "ansible_local" do |ansible|
      ansible.playbook = "ansible-webbooks/site.yml"
      ansible.inventory_path = "ansible-webbooks/hosts"
      ansible.limit = "debian"  # Соответствует группе в hosts-файле
      ansible.verbose = "vvvv"
    end
  end

  # Конфигурация для CentOS
  config.vm.define "centos" do |centos|
    centos.vm.box = "centos/stream8"
    centos.vm.provider "virtualbox" do |vb|
      vb.memory = "2048"
      vb.cpus = 2
    end
    
    centos.vm.provision "shell", inline: <<-SHELL
      yum install -y python3-pip git
      pip3 install ansible==5.10.0
    SHELL
    
    centos.vm.provision "ansible_local" do |ansible|
      ansible.playbook = "ansible-webbooks/site.yml"
      ansible.inventory_path = "ansible-webbooks/hosts"
      ansible.limit = "centos"  # Соответствует группе в hosts-файле
      ansible.verbose = "vvvv"
    end
  end
end