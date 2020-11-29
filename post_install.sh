git clone https://github.com/monicahq/monica.git /var/www/
cd /var/www/monica
git checkout tags/v2.19.1

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

if [ -e "/root/.mysql_secret" ] ; then
   # Mysql > 57 sets a default PW on root
   TMPPW=$(cat /root/.mysql_secret | grep -v "^#")
   echo "SQL Temp Password: $TMPPW"

# Configure mysql
mysql -u root -p"${TMPPW}" --connect-expired-password <<-EOF
CREATE DATABASE ${DB} CHARACTER SET utf8 COLLATE utf8_general_ci;
ALTER USER 'root'@'localhost' IDENTIFIED BY '${PASS}';
CREATE USER '${USER}'@'localhost' IDENTIFIED BY '${PASS}';
GRANT ALL PRIVILEGES ON *.* TO '${USER}'@'localhost' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON ${DB}.* TO '${USER}'@'localhost';
FLUSH PRIVILEGES;
EOF

else
   # Mysql <= 56 does not

# Configure mysql
mysql -u root <<-EOF
CREATE DATABASE ${DB} CHARACTER SET utf8 COLLATE utf8_general_ci;
UPDATE mysql.user SET Password=PASSWORD('${PASS}') WHERE User='root';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.db WHERE Db='test' OR Db='test_%';
CREATE USER '${USER}'@'localhost' IDENTIFIED BY '${PASS}';
GRANT ALL PRIVILEGES ON *.* TO '${USER}'@'localhost' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON ${DB}.* TO '${USER}'@'localhost';
FLUSH PRIVILEGES;
EOF
fi

cd /var/www/monica/
cat <<EOF
#
# Welcome, friend ❤. Thanks for trying out Monica. We hope you'll have fun.
#

# Two choices: local|production. Use local if you want to install Monica as a
# development version. Use production otherwise.
APP_ENV=local

# true if you want to show debug information on errors. For production, put this
# to false.
APP_DEBUG=false

# The encryption key. This is the most important part of the application. Keep
# this secure otherwise, everyone will be able to access your application.
# Must be 32 characters long exactly.
# Use `php artisan key:generate` or `pwgen -s 32 1` to generate a random key.
APP_KEY=$(pwgen -s 32 1)

# Prevent information leakage by referring to IDs with hashIds instead of
# the actual IDs used in the database.
HASH_SALT=$(pwgen -s 25 1)
Hash_LENGTH=18

# The URL of your application.
APP_URL=http://localhost

# Force using APP_URL as base url of your application.
# You should not need this, unless you are using subdirectory config.
APP_FORCE_URL=false

# Database information
# To keep this information secure, we urge you to change the default password
# Currently only "mysql" compatible servers are working
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
# You can use mysql unix socket if available, it overrides DB_HOST and DB_PORT values.
#DB_UNIX_SOCKET=/var/run/mysqld/mysqld.sock
DB_DATABASE=${DB}
DB_USERNAME=${USER}
DB_PASSWORD=${PASS}
DB_PREFIX=
DB_TEST_HOST=127.0.0.1
#DB_TEST_DATABASE=monica_test
#DB_TEST_USERNAME=homestead
#DB_TEST_PASSWORD=secret

# Use utf8mb4 database charset format to support emoji characters
# ⚠ be sure your DBMS supports utf8mb4 format
DB_USE_UTF8MB4=true

# Mail credentials used to send emails from the application.
#MAIL_MAILER=smtp
#MAIL_HOST=mailtrap.io
#MAIL_PORT=2525
#MAIL_USERNAME=
#MAIL_PASSWORD=
#MAIL_ENCRYPTION=
# Outgoing emails will be sent with these identity
#MAIL_FROM_ADDRESS=
#MAIL_FROM_NAME="Monica instance"
# New registration notification sent to this email
#APP_EMAIL_NEW_USERS_NOTIFICATION=

# Ability to disable signups on your instance.
# Can be true or false. Default to false.
APP_DISABLE_SIGNUP=true

# Enable user email verification.
APP_SIGNUP_DOUBLE_OPTIN=false

# Set trusted proxy IP addresses.
# To trust all proxies that connect directly to your server, use a "*".
# To trust one or more specific proxies that connect directly to your server,
# use a comma separated list of IP addresses.
APP_TRUSTED_PROXIES=

# Enable automatic cloudflare trusted proxy discover
APP_TRUSTED_CLOUDFLARE=false

# Frequency of creation of new log files. Logs are written when an error occurs.
# Refer to config/logging.php for the possible values.
LOG_CHANNEL=daily

# Error tracking. Specific to hosted version on .com. You probably don't need
# those.
SENTRY_SUPPORT=false
SENTRY_LARAVEL_DSN=

# Send a daily ping to https://version.monicahq.com to check if a new version
# is available. When a new version is detected, you will have a message in the
# UI, as well as the release notes for the new changes. Can be true or false.
# Default to true.
CHECK_VERSION=true

# Cache, session, and queue parameters
# ⚠ Change this only if you know what you are doing
#. Cache: database, file, memcached, redis, dynamodb
#. Session: file, cookie, database, apc, memcached, redis, array
#. Queue: sync, database, beanstalkd, sqs, redis
#  If Queue is not set to 'sync', you'll have to set a queue worker
#  See https://laravel.com/docs/5.7/queues#running-the-queue-worker
CACHE_DRIVER=database
SESSION_DRIVER=file
SESSION_LIFETIME=120
QUEUE_CONNECTION=sync

# If you use redis, set the redis host or ip, like:
#REDIS_HOST=redis

# Maximum allowed size for uploaded files, in kilobytes.
# Make sure this is an integer, without commas or spaces.
DEFAULT_MAX_UPLOAD_SIZE=10240

# Maximum allowed storage size per account, in megabytes.
# Make sure this is an integer, without commas or spaces.
DEFAULT_MAX_STORAGE_SIZE=512

# Default filesystem to store uploaded files.
# Possible values: public|s3
DEFAULT_FILESYSTEM=public

# AWS keys for S3 when using this storage method
AWS_KEY=
AWS_SECRET=
AWS_REGION=us-east-1
AWS_BUCKET=
AWS_SERVER=

# Allow Two Factor Authentication feature on your instance
MFA_ENABLED=true

# Enable DAV support
DAV_ENABLED=true

# CLIENT ID and SECRET used for OAuth authentication
PASSPORT_PERSONAL_ACCESS_CLIENT_ID=
PASSPORT_PERSONAL_ACCESS_CLIENT_SECRET=

# Allow to access general statistics about your instance through a public API
# call
ALLOW_STATISTICS_THROUGH_PUBLIC_API_ACCESS=false

# Indicates that each user in the instance must comply to international policies
# like CASL or GDPR
POLICY_COMPLIANT=true

# Enable geolocation services
# This is used to translate addresses to GPS coordinates.
ENABLE_GEOLOCATION=false

# API key for geolocation services
# We use LocationIQ (https://locationiq.com/) to translate addresses to
# latitude/longitude coordinates. We could use Google instead but we don't
# want to give anything to Google, ever.
# LocationIQ offers 10,000 free requests per day.
LOCATION_IQ_API_KEY=

# Enable weather on contact profile page
# Weather can only be fetched if we know longitude/latitude - this is why
# you also need to activate the geolocation service above to make it work
ENABLE_WEATHER=false

# Access to weather data from darksky api
# https://darksky.net/dev/register
# Darksky provides an api with 1000 free API calls per day
# You need to enable the weather above if you provide an API key here.
DARKSKY_API_KEY=
EOF > .env

composer install --no-interaction --no-suggest --no-dev --ignore-platform-reqs
php artisan setup:production -v


chgrp -R www-data /var/www/monica
chmod -R 775 /var/www/monica/storage
a2enmod rewrite
a2dissite 000-default.conf
a2ensite monica.conf
service apache2 restart

cat "Welcome, I am monica" >> /root/PLUGIN_INFO
