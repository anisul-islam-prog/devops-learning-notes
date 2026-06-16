#!/bin/bash
set -e

exec > >(tee /var/log/user-data.log) 2>&1
echo "Starting Zabbix installation at $(date)"

# Update system
apt-get update -y
apt-get upgrade -y

# Install Apache and PHP FIRST
apt-get install -y \
    apache2 \
    php \
    libapache2-mod-php \
    php-mysql \
    php-gd \
    php-bcmath \
    php-mbstring \
    php-xml \
    php-ldap \
    php-json \
    php-curl \
    php-zip \
    php-intl \
    php-fpm \
    mysql-server-8.0 \
    gnupg \
    curl \
    software-properties-common

# Start Apache and MySQL immediately
systemctl start apache2
systemctl start mysql

# Configure MySQL
mysql -e "CREATE DATABASE IF NOT EXISTS zabbix CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;" || true
mysql -e "CREATE USER IF NOT EXISTS 'zabbix'@'localhost' IDENTIFIED BY 'zabbix_password';" || true
mysql -e "GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'localhost';" || true
mysql -e "SET GLOBAL log_bin_trust_function_creators = 1;" || true
mysql -e "FLUSH PRIVILEGES;" || true

# Install Zabbix 7.0
wget -q https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_7.0-2+ubuntu22.04_all.deb
dpkg -i zabbix-release_7.0-2+ubuntu22.04_all.deb
apt-get update -y

apt-get install -y \
    zabbix-server-mysql \
    zabbix-frontend-php \
    zabbix-apache-conf \
    zabbix-sql-scripts \
    zabbix-agent \
    zabbix-get

# Import schema (only if tables don't exist)
TABLE_COUNT=$(mysql -uzabbix -pzabbix_password zabbix -e "SHOW TABLES;" 2>/dev/null | wc -l || echo "0")
if [ "$TABLE_COUNT" -lt "5" ]; then
    zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql --default-character-set=utf8mb4 -uzabbix -pzabbix_password zabbix
fi

mysql -e "SET GLOBAL log_bin_trust_function_creators = 0;" || true

# Configure Zabbix Server
sed -i 's/# DBPassword=/DBPassword=zabbix_password/' /etc/zabbix/zabbix_server.conf

# Configure PHP
PHP_INI=$(php -r "echo php_ini_loaded_file();")
sed -i 's/post_max_size = 8M/post_max_size = 16M/' "$PHP_INI"
sed -i 's/max_execution_time = 30/max_execution_time = 300/' "$PHP_INI"
sed -i 's/max_input_time = 60/max_input_time = 300/' "$PHP_INI"
sed -i 's/;date.timezone =/date.timezone = Asia\/Dhaka/' "$PHP_INI"

# Ensure Zabbix Apache config is enabled
if [ -f /etc/apache2/conf-available/zabbix.conf ]; then
    a2enconf zabbix
else
    # Create config if missing
    tee /etc/apache2/conf-available/zabbix.conf << 'EOF'
Alias /zabbix /usr/share/zabbix

<<Directory "/usr/share/zabbix">
    Options FollowSymLinks
    AllowOverride None
    Require all granted
</Directory>

<<Directory "/usr/share/zabbix/conf">
    Require all denied
</Directory>

<<Directory "/usr/share/zabbix/app">
    Require all denied
</Directory>

<<Directory "/usr/share/zabbix/include">
    Require all denied
</Directory>

<<Directory "/usr/share/zabbix/local">
    Require all denied
</Directory>
EOF
    a2enconf zabbix
fi

a2enmod rewrite
systemctl restart apache2

# Start Zabbix services
systemctl restart zabbix-server zabbix-agent apache2
systemctl enable zabbix-server zabbix-agent apache2

# Install Zabbix Agent 2
apt-get install -y zabbix-agent2
systemctl enable zabbix-agent2
systemctl start zabbix-agent2

# Verify Apache can serve PHP
echo "<?php phpinfo(); ?>" > /var/www/html/info.php

echo "Zabbix installation completed at $(date)"
echo "Zabbix URL: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)/zabbix"
echo "Test PHP: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)/info.php"