#!/bin/bash
set -e

exec > >(tee /var/log/user-data.log) 2>&1
echo "Starting Zabbix installation at $(date)"

# Update system
apt-get update -y
apt-get upgrade -y

# Install dependencies
apt-get install -y \
    apache2 \
    mysql-server-8.0 \
    php \
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
    libapache2-mod-php \
    gnupg \
    curl \
    software-properties-common

# Configure MySQL
mysql -e "CREATE DATABASE zabbix CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;"
mysql -e "CREATE USER 'zabbix'@'localhost' IDENTIFIED BY 'zabbix_password';"
mysql -e "GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'localhost';"
mysql -e "SET GLOBAL log_bin_trust_function_creators = 1;"
mysql -e "FLUSH PRIVILEGES;"

# Install Zabbix 7.0 LTS
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

# Import initial schema
zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql --default-character-set=utf8mb4 -uzabbix -pzabbix_password zabbix

# Reset MySQL setting
mysql -e "SET GLOBAL log_bin_trust_function_creators = 0;"

# Configure Zabbix Server
sed -i 's/# DBPassword=/DBPassword=zabbix_password/' /etc/zabbix/zabbix_server.conf

# Configure PHP for Zabbix
sed -i 's/post_max_size = 8M/post_max_size = 16M/' /etc/php/8.1/apache2/php.ini
sed -i 's/max_execution_time = 30/max_execution_time = 300/' /etc/php/8.1/apache2/php.ini
sed -i 's/max_input_time = 60/max_input_time = 300/' /etc/php/8.1/apache2/php.ini
sed -i 's/;date.timezone =/date.timezone = Asia\/Dhaka/' /etc/php/8.1/apache2/php.ini

# Configure Apache for Zabbix
cat > /etc/apache2/conf-available/zabbix.conf << 'EOF'
Alias /zabbix /usr/share/zabbix

<Directory "/usr/share/zabbix">
    Options FollowSymLinks
    AllowOverride None
    Require all granted

    <IfModule mod_php.c>
        php_value max_execution_time 300
        php_value memory_limit 128M
        php_value post_max_size 16M
        php_value upload_max_filesize 2M
        php_value max_input_time 300
        php_value max_input_vars 10000
        php_value always_populate_raw_post_data -1
        php_value date.timezone Asia/Dhaka
    </IfModule>
</Directory>

<Directory "/usr/share/zabbix/conf">
    Require all denied
</Directory>

<Directory "/usr/share/zabbix/app">
    Require all denied
</Directory>

<Directory "/usr/share/zabbix/include">
    Require all denied
</Directory>

<Directory "/usr/share/zabbix/local">
    Require all denied
</Directory>
EOF

a2enconf zabbix
a2enmod rewrite
systemctl restart apache2

# Start Zabbix services
systemctl restart zabbix-server zabbix-agent apache2
systemctl enable zabbix-server zabbix-agent apache2

# Install Zabbix Agent 2 (modern replacement)
apt-get install -y zabbix-agent2
systemctl enable zabbix-agent2
systemctl start zabbix-agent2

echo "Zabbix installation completed at $(date)"