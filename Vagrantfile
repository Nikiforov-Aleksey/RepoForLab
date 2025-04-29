Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/focal64"
  config.vm.boot_timeout = 600
  
  # Отключение проверки новых версий бокса
  config.vm.box_check_update = false
  
  # DB сервер
  config.vm.define "db" do |db|
    db.vm.hostname = "webbooks-db"
    db.vm.network "private_network", ip: "192.168.56.10"
    db.vm.provider "virtualbox" do |vb|
      vb.memory = "1024"
      vb.cpus = 1
    end
    db.vm.provision "shell", inline: <<-SHELL
      apt-get update
      apt-get install -y python3
    SHELL
  end
  
  # Аналогично для app и front
  config.vm.define "app" do |app|
    app.vm.hostname = "webbooks-app"
    app.vm.network "private_network", ip: "192.168.56.11"
    app.vm.provider "virtualbox" do |vb|
      vb.memory = "1024"
      vb.cpus = 1
    end
  end
  
  config.vm.define "front" do |front|
    front.vm.hostname = "webbooks-front"
    front.vm.network "private_network", ip: "192.168.56.12"
    front.vm.provider "virtualbox" do |vb|
      vb.memory = "512"
      vb.cpus = 1
    end
  end
end