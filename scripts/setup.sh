#!/bin/bash

# Базовые утилиты
apt-get update
apt-get install -y curl wget git unzip

# Установка OpenJDK 11
apt-get install -y openjdk-11-jdk

# Установка Maven
apt-get install -y maven

# Установка PostgreSQL
apt-get install -y postgresql postgresql-contrib

# Настройка времени
apt-get install -y ntp
systemctl enable ntp
systemctl start ntp

# Настройка локали
apt-get install -y language-pack-ru
update-locale LANG=ru_RU.UTF-8

# Настройка SSH
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/g' /etc/ssh/sshd_config
sed -i 's/PasswordAuthentication no/#PasswordAuthentication no/g' /etc/ssh/sshd_config
systemctl restart sshd

# Добавление пользователя vagrant в sudoers без пароля
echo "vagrant ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

