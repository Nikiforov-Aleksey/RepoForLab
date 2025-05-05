def deployScript = '''
#!/bin/bash
set -ex

# Проверяем артефакт
if [ ! -f "/tmp/webbooks.jar" ]; then
    echo "ERROR: Артефакт не найден в /tmp/webbooks.jar"
    exit 1
fi

# Проверяем, что файл является валидным JAR-архивом
if ! jar -tf /tmp/webbooks.jar >/dev/null 2>&1; then
    echo "ERROR: Файл не является валидным JAR-архивом"
    exit 1
fi

# Останавливаем сервис
sudo systemctl stop webbooks || true

# Бэкап предыдущей версии
[ -f "/opt/webbooks/webbooks.jar" ] && sudo cp /opt/webbooks/webbooks.jar /opt/webbooks/webbooks.jar.bak

# Развертываем новую версию
sudo cp /tmp/webbooks.jar /opt/webbooks/webbooks.jar
sudo chown webbooks:webbooks /opt/webbooks/webbooks.jar

# Перезагружаем systemd (если конфиг изменился)
sudo systemctl daemon-reload

# Запускаем сервис
echo "Запуск сервиса webbooks..."
sudo systemctl start webbooks

# Проверяем статус
sleep 5
service_status=$(sudo systemctl is-active webbooks)
if [ "$service_status" != "active" ]; then
    echo "ERROR: Не удалось запустить сервис. Текущий статус: $service_status"
    sudo journalctl -u webbooks -n 50 --no-pager
    exit 1
fi
echo "Сервис успешно запущен"
'''
