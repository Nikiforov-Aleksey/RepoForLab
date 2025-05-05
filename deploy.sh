def deployScript = '''
#!/bin/bash
set -ex

# Проверяем наличие артефакта
if [ ! -f "/tmp/webbooks.jar" ]; then
    echo "ERROR: Артефакт не найден в /tmp/webbooks.jar"
    exit 1
fi

# Останавливаем сервис (если запущен)
sudo systemctl stop webbooks || true

# Бэкап предыдущей версии (опционально)
sudo cp /opt/webbooks/webbooks.jar /opt/webbooks/webbooks.jar.bak || true

# Развертываем новую версию
sudo cp /tmp/webbooks.jar /opt/webbooks/webbooks.jar
sudo chown webbooks:webbooks /opt/webbooks/webbooks.jar

# Запускаем сервис с детальным логгированием
echo "Запуск сервиса webbooks..."
sudo systemctl start webbooks

# Ожидаем и проверяем
sleep 5
service_status=$(sudo systemctl is-active webbooks)
if [ "$service_status" != "active" ]; then
    echo "ERROR: Не удалось запустить сервис. Текущий статус: $service_status"
    sudo journalctl -u webbooks -n 50 --no-pager
    exit 1
fi

echo "Сервис успешно запущен"
'''
