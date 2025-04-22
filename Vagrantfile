ENV['VAGRANT_SERVER_URL'] = 'https://vagrant.elab.pro'
BRIDGE_NET="192.168.56."

DOMAIN="test"

MACHINES = {
  :lu_ubuntu => {
    # :box_name => "ubuntu/focal64", # Также, можно указать URL откуда стянуть нужный box если такой есть
    :box_name => "my-new-box", # Также, можно указать URL откуда стянуть нужный box если такой есть
    :host_name => "my-new-box",  
    :ip_addr => BRIDGE_NET + "101",
    :cpu => 2,
    :ram => 4048, # Megabytes
    :needs_controller => false,
    :controller_name => 'SATA Controller',
  },
}

# Входим в Главную конфигурацию vagrant версии 2
Vagrant.configure("2") do |config|
    # Добавить шару между хостовой и гостевой машиной
    #config.vm.synced_folder "D://hostmachine/shared/folder", "/src/shara"
    config.vm.synced_folder "../", "/devops"
    
    # Отключить дефолтную шару
    #config.vm.synced_folder ".", "/vagrant", disabled: true
    
    MACHINES.each do |boxname, boxconfig|                   # Проходим по элементах массива MACHINES
        config.vm.define boxname do |box|
            box.vm.box = boxconfig[:box_name]               # Поднять машину из образа
            box.vm.host_name = boxconfig[:host_name]        # Hostname который будет присвоен VM (самой ОС)
            # box.vm.usable_port_range = (2200..2250)         # Пул портов, который будет использоваться для подключения к каждый VM через 127.0.0.1
            # box.vm.network "private_network", ip: boxname[:ip], name: "VirtualBox Host-Only Ethernet Adapter" # Добавление и настройка внутреннего сетевого адаптера (Intranet)
            box.vm.network "private_network", ip: boxconfig[:ip_addr]
            # Тонкие настройки для конкретного провайдера (в нашем случае - VBoxManage)
            box.vm.provider :virtualbox do |vb|
                vb.name = boxconfig[:host_name]     # Можно перезаписать название VM в Vbox GUI
                vb.cpus = boxconfig[:cpu]
                vb.memory = boxconfig[:ram]
                # Добавление жесткого диска, если такой указан в конфигурации
                if (!boxconfig[:disks].nil?)
                  # needsController = true
                  boxconfig[:disks].each do |dname, dconf|
                    unless File.exist?(dconf[:dfile])       # Не создавать диск, если он уже существует
                      vb.customize ['createhd', '--filename', dconf[:dfile], '--variant', 'Fixed', '--size', dconf[:size]]
                    end
                    # needsController =  true
                  end
                  if boxconfig[:needs_controller] == true
                  # if needsController == true
                    vb.customize ["storagectl", :id, "--name", boxconfig[:controller_name], "--add", "sata" ]
                  end
                  boxconfig[:disks].each do |dname, dconf|
                    vb.customize ['storageattach', :id,  '--storagectl', boxconfig[:controller_name], '--port', dconf[:port], '--device', 0, '--type', 'hdd', '--medium', dconf[:dfile]]
                  end
                  # end
                end
            end
 	    
            # Включение ssh агента
            config.ssh.forward_agent = true
            # Провижининг ОС настроечными скриптами
            box.vm.provision "shell", path: "scripts/setup_ssh.sh"
            box.vm.provision "shell", path: "scripts/nginx.sh"
        end
    end
end
