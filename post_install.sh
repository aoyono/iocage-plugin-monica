#!/bin/sh

# Enable the services
sysrc -f /etc/rc.conf apache24_enable="YES"
sysrc -f /etc/rc.conf mysql_enable="YES"
# We install Redis to make it available in case there is a need to use it
# But we default to not use it as Monica team recommend to use it only
# for fun or when there are many users
sysrc -f /etc/rc.conf redis_enable="NO"

# install the web app
CURRENT_VERSION=v2.19.1
git clone https://github.com/monicahq/monica.git /usr/local/www/monica
cd /usr/local/www/monica
git checkout tags/${CURRENT_VERSION}

# Because we clone the web app, /usr/local/www/monica needs to be inexistent by the time we do clone, but we need .env there. Move it from the
# plugin overlay place to the newly created /usr/local/www/monica
mv /usr/local/www/.env /usr/local/www/monica/.env

# Setup the database
USER="monica-dbadmin"
DB="monica"

# Save the config values
echo "$DB" > /root/dbname
echo "$USER" > /root/dbuser
export LC_ALL=C
cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1 > /root/dbpassword
PASS=$(cat /root/dbpassword)

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

# Setup some values to the .env file
sed -i '' "s/.*APP_KEY=.*/APP_KEY=${APP_KEY}/" /usr/local/www/monica/.env
sed -i '' "s/.*HASH_SALT=.*/HASH_SALT=${HASH_SALT}/" /usr/local/www/monica/.env
sed -i '' "s/.*APP_URL=.*/APP_URL=http:\/\/${JAIL_IP}/" /usr/local/www/monica/.env
sed -i '' "s/.*DB_DATABASE=.*/DB_DATABASE=${DB}/" /usr/local/www/monica/.env
sed -i '' "s/.*DB_USERNAME=.*/DB_USERNAME=${USER}/" /usr/local/www/monica/.env
sed -i '' "s/.*DB_PASSWORD=.*/DB_PASSWORD=${PASS}/" /usr/local/www/monica/.env

# Set the server name to point to the IP address of the created jail
sed -i '' "s/\(.*\)ServerName.*/\1ServerName ${JAIL_IP}/" /usr/local/etc/apache24/Includes/monica.conf

# Explicitly activate mod_php for apache - usually, when installing mod_apache from the cli, this line is added as a post install
# But we need to do it here because we are providing httpd.conf as an overlay to the plugin (which is probably copied to the plugin fs after all packages have been installed)
sed -i '' "s/^# \(LoadModule php7_module\)\(.*\)/\1 \2/" /usr/local/etc/apache24/httpd.conf

cp /usr/local/etc/php.ini-production /usr/local/etc/php.ini
rehash

# Configure the web app
composer install --no-interaction --no-suggest --no-dev --ignore-platform-reqs
php artisan key:generate
php artisan setup:production -vvv --force

# Encryption keys for the API
php artisan passport:keys
php artisan passport:client --personal --no-interaction

{
  echo ''
  echo "PASSPORT_PRIVATE_KEY=\"$(tr -d '\r\n' </usr/local/www/monica/storage/oauth-private.key)\""
  echo ''
  echo "PASSPORT_PUBLIC_KEY=\"$(tr -d '\r\n' </usr/local/www/monica/storage/oauth-public.key)\""
} >> /usr/local/www/monica/.env

APACHE_USER=www

chgrp -R ${APACHE_USER} /usr/local/www/monica
chmod -R 775 /usr/local/www/monica/storage

service apache24 restart

echo "* * * * *   /usr/bin/php /var/www/monica/artisan schedule:run >> /dev/null 2>&1" | crontab -u ${APACHE_USER} -

{
  echo "Welcome to monica, a PRM"
  echo "The name of the database is: $DB"
  echo "The administrator of the database is: $USER"
  echo "The password of the database administrator is: $PASS"
} >> /root/PLUGIN_INFO

echo "The acme.sh client is available for use if you want to setup https. More info at: https://github.com/acmesh-official/acme.sh"
