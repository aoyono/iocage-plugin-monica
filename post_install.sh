#!/bin/sh

# Enable the services
sysrc -f /etc/rc.conf apache24_enable="YES"
sysrc -f /etc/rc.conf mysql_enable="YES"
sysrc -f /etc/rc.conf redis_enable="YES"

git clone https://github.com/monicahq/monica.git /usr/local/www/monica
cd /usr/local/www/monica
git checkout tags/v2.19.1

cp /usr/local/www/.env /usr/local/www/monica/.env

# Setup the database
USER="dbadmin"
DB="monica"
MNCUSER="mncadmin"

# Save the config values
echo "$DB" > /root/dbname
echo "$USER" > /root/dbuser
echo "$MNCUSER" > /root/mncuser
export LC_ALL=C
cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1 > /root/dbpassword
cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1 > /root/mncpassword
PASS=`cat /root/dbpassword`
MNCPASS=`cat /root/mncpassword`

service mysql-server start
service redis start
service apache24 start

# Mysql > 57 sets a default PW on root
TMPPW=$(cat /root/.mysql_secret | grep -v "^#")
echo "SQL Temp Password: $TMPPW"

# Configure mysql
mysql -u root -p"${TMPPW}" --connect-expired-password <<-EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${PASS}';
CREATE USER '${USER}'@'localhost' IDENTIFIED BY '${PASS}';
GRANT ALL PRIVILEGES ON *.* TO '${USER}'@'localhost' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON ${DB}.* TO '${USER}'@'localhost';

CREATE DATABASE ${DB} CHARACTER SET utf8 COLLATE utf8_general_ci;

FLUSH PRIVILEGES;
EOF


JAIL_IP=$(ifconfig epair0b | grep 'inet' | awk -F ' ' '{ print $2 }')
APP_KEY=$(pwgen -s 32 1)
HASH_SALT=$(pwgen -s 25 1)


sed -i '' "s/.*APP_KEY=.*/APP_KEY=${APP_KEY}/" /usr/local/www/monica/.env
sed -i '' "s/.*HASH_SALT=.*/HASH_SALT=${HASH_SALT}/" /usr/local/www/monica/.env
sed -i '' "s/.*APP_URL=.*/APP_URL=http://${JAIL_IP}/" /usr/local/www/monica/.env
sed -i '' "s/.*DB_DATABASE=.*/DB_DATABASE=${DB}/" /usr/local/www/monica/.env
sed -i '' "s/.*DB_USERNAME=.*/DB_USERNAME=${USER}/" /usr/local/www/monica/.env
sed -i '' "s/.*DB_PASSWORD=.*/DB_PASSWORD=${PASS}/" /usr/local/www/monica/.env
sed -i '' "s/.*REDIS_HOST=.*/REDIS_HOST=${JAIL_IP}/" /usr/local/www/monica/.env

sed -i '' "s/\(.*\)Servername.*/\1ServerName ${JAIL_IP}/" /usr/local/etc/apache24/Includes/monica.conf
sed -i '' "s/^# \(LoadModule php7_module\)\(.*\)/\1 \2/" /usr/local/etc/apache24/httpd.conf


cp /usr/local/etc/php.ini-production /usr/local/etc/php.ini
rehash

composer install --no-interaction --no-suggest --no-dev --ignore-platform-reqs
php artisan setup:production -vvv --no-interaction

chgrp -R www /usr/local/www/monica
chmod -R 775 /usr/local/www/monica/storage

service apache24 restart

echo "Welcome, I am monica" >> /root/PLUGIN_INFO
