#!/bin/bash
set -euo pipefail

# Логирование
LOG_FILE="/var/log/webbooks_install.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== Начало установки WebBooks ==="
date

# 1. Создание пользователя webbooks
echo "Создание пользователя webbooks..."
if ! id -u webbooks >/dev/null 2>&1; then
    sudo useradd -m -s /bin/bash -G sudo webbooks  {
        echo "Ошибка создания пользователя webbooks" >&2
        exit 1
    }
    echo "webbooks:webbooks" | sudo chpasswd
else
    echo "Пользователь webbooks уже существует"
fi

# 2. Установка зависимостей
echo "Установка зависимостей..."
sudo apt update
sudo apt install -y curl wget

# 3. Установка OpenJDK 17
echo "Установка OpenJDK 17..."
if [ ! -d "/opt/jdk-17.0.1" ]; then
    wget -q 'https://download.java.net/java/GA/jdk17.0.1/2a2082e5a09d4267845be086888add4f/12/GPL/openjdk-17.0.1_linux-x64_bin.tar.gz'  {
        echo "Ошибка загрузки JDK" >&2
        exit 1
    }
    tar -xzf openjdk-17.0.1_linux-x64_bin.tar.gz
    sudo mv jdk-17.0.1 /opt/
    rm openjdk-17.0.1_linux-x64_bin.tar.gz
else
    echo "OpenJDK уже установлен"
fi

# 4. Установка Maven
echo "Установка Maven..."
if [ ! -d "/opt/apache-maven-3.2.5" ]; then
    wget -q https://archive.apache.org/dist/maven/maven-3/3.2.5/binaries/apache-maven-3.2.5-bin.tar.gz  {
        echo "Ошибка загрузки Maven" >&2
        exit 1
    }
    tar -xzf apache-maven-3.2.5-bin.tar.gz
    sudo mv apache-maven-3.2.5 /opt/
    rm apache-maven-3.2.5-bin.tar.gz
else
    echo "Maven уже установлен"
fi

# 5. Настройка переменных окружения
echo "Настройка окружения..."
ENV_FILE="/home/webbooks/.profile"
sudo -u webbooks bash -c "cat > $ENV_FILE" <<'EOL'
export JAVA_HOME='/opt/jdk-17.0.1'
export PATH="$JAVA_HOME/bin:$PATH"
export M2_HOME='/opt/apache-maven-3.2.5'
export PATH="$M2_HOME/bin:$PATH"
EOL

# 6. Установка и настройка PostgreSQL
echo "Установка PostgreSQL..."
if ! dpkg -l | grep -q postgresql-12; then
    curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg
    echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" | sudo tee /etc/apt/sources.list.d/pgdg.list
    sudo apt update
    sudo apt install -y postgresql-12 postgresql-client-12  {
        echo "Ошибка установки PostgreSQL" >&2
        exit 1
    }

    # Проверка и запуск кластера
    if ! sudo pg_isready -q; then
        echo "Запуск кластера PostgreSQL..."
        sudo pg_createcluster 12 main --start
        sudo pg_ctlcluster 12 main start  {
            echo "Ошибка запуска кластера PostgreSQL" >&2
            exit 1
        }
    fi

    # Настройка PostgreSQL
    sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD 'webbooks';"
    sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/12/main/postgresql.conf
    echo "host all all 0.0.0.0/0 md5" | sudo tee -a /etc/postgresql/12/main/pg_hba.conf
    sudo systemctl restart postgresql

    # Создание БД
    sudo -u postgres psql -c "CREATE DATABASE webbooks_db;"  {
        echo "Ошибка создания БД" >&2
        exit 1
    }

    # Импорт данных
    DATA_FILE="/home/naa/2025-02-example/apps/webbooks/src/main/resources/data.sql"
    if [ -f "$DATA_FILE" ]; then
        sudo -u postgres psql webbooks_db < "$DATA_FILE"  {
            echo "Ошибка импорта данных" >&2
            exit 1
        }
    fi
else
    echo "PostgreSQL уже установлен"
    sudo systemctl restart postgresql
fi

# 7. Копирование проекта
echo "Копирование проекта..."
APP_SRC_DIR="/home/naa/2025-02-example"
APP_DEST_DIR="/home/webbooks/2025-02-example"

if [ ! -d "$APP_SRC_DIR" ]; then
    echo "Исходная директория приложения $APP_SRC_DIR не найдена!" >&2
    exit 1
fi

sudo mkdir -p "$APP_DEST_DIR"
sudo cp -r "$APP_SRC_DIR" "$(dirname "$APP_DEST_DIR")"  {
    echo "Ошибка копирования проекта" >&2
    exit 1
}
sudo chown -R webbooks:webbooks "$APP_DEST_DIR"
sudo chmod -R 755 "$APP_DEST_DIR"
# 8. Настройка приложения
echo "Настройка конфигурации приложения..."
APP_PROPERTIES="$APP_DEST_DIR/apps/webbooks/src/main/resources/application.properties"
sudo -u webbooks bash -c "cat > $APP_PROPERTIES" <<EOL
spring.datasource.driver-class-name=org.postgresql.Driver
spring.datasource.url=jdbc:postgresql://localhost:5432/webbooks_db
spring.datasource.username=postgres
spring.datasource.password=webbooks
spring.jpa.hibernate.ddl-auto=validate
spring.jpa.properties.hibernate.dialect=org.hibernate.dialect.PostgreSQLDialect
EOL

# 9. Сборка приложения (пропуск тестов)
echo "Сборка приложения..."
cd "$APP_DEST_DIR/apps/webbooks"
sudo -u webbooks ./mvnw clean package -DskipTests  {
    echo "Ошибка сборки приложения" >&2
    exit 1
}

# 10. Настройка systemd
echo "Настройка systemd..."
SERVICE_FILE="/etc/systemd/system/webbooks.service"
sudo bash -c "cat > $SERVICE_FILE" <<EOL
[Unit]
Description=Webbooks Java Application
After=network.target postgresql.service
Requires=postgresql.service

[Service]
User=webbooks
WorkingDirectory=$APP_DEST_DIR/apps/webbooks
Environment="JAVA_OPTS=-Xms256m -Xmx512m -Dspring.profiles.active=prod"
ExecStart=/opt/jdk-17.0.1/bin/java \$JAVA_OPTS -jar $APP_DEST_DIR/apps/webbooks/target/DigitalLibrary-0.0.1-SNAPSHOT.jar
SuccessExitStatus=143
Restart=always
RestartSec=5
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
EOL

sudo systemctl daemon-reload
sudo systemctl enable webbooks.service
sudo systemctl start webbooks.service  {
    echo "Ошибка запуска сервиса" >&2
    journalctl -u webbooks.service -n 50 --no-pager
    exit 1
}

# 11. Установка и настройка Nginx
echo "Установка Nginx..."
if ! dpkg -l | grep -q nginx; then
    sudo apt install -y nginx  {
        echo "Ошибка установки Nginx" >&2
        exit 1
    }
fi

echo "Настройка Nginx..."
sudo mkdir -p /var/www/webbooks/html
NGINX_CONFIG="/etc/nginx/sites-available/webbooks"
sudo bash -c "cat > $NGINX_CONFIG" <<EOL
server {
    listen 80;
    listen [::]:80;

    server_name webbooks  webbooks.local;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    access_log /var/log/nginx/webbooks_access.log;
    error_log /var/log/nginx/webboks_error.log;
}
EOL

sudo ln -sf "$NGINX_CONFIG" /etc/nginx/sites-enabled/
sudo nginx -t  {
    echo "Ошибка конфигурации Nginx" >&2
    exit 1
}
sudo systemctl reload nginx

# 12. Настройка hosts
echo "Настройка /etc/hosts..."
if ! grep -q "webbooks.local" /etc/hosts; then
    sudo sed -i "1s/^/127.0.0.1 webbooks www.webbooks.local\n/" /etc/hosts
fi

echo "=== Установка завершена успешно! ==="
echo "Приложение доступно по адресу: http://webbooks.local"
echo "Логи установки: $LOG_FILE"
date
