#!/bin/bash

# Установка Ansible
sudo apt update
sudo apt install -y ansible

# Запуск Ansible
ansible-playbook /vagrant/ansible/site.yml -i /vagrant/ansible/inventory/hosts.ini