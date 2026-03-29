#!/bin/bash

# ---------------------------
# Start SSH for Hadoop communication
# ---------------------------
/etc/init.d/ssh start

# ---------------------------
# Initialize MySQL data directory if missing
# ---------------------------
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "Initializing MySQL data directory..."
    mysqld --initialize-insecure --user=mysql
else
    echo "MySQL data directory already initialized."
fi

# ---------------------------
# Start MySQL (MariaDB)
# ---------------------------
#service mariadb start
# ---------------------------
# Start MySQL (MariaDB) manually in background
# ---------------------------
echo "Starting MariaDB manually..."
/usr/sbin/mysqld --user=mysql --skip-networking=0 --bind-address=0.0.0.0 &
MYSQL_PID=$!

# Wait until MySQL is ready
#until mysqladmin ping -u root --silent; do
#    echo "Waiting for MySQL..."
#    sleep 2
#done
# ---------------------------
# Wait until MySQL is ready
# ---------------------------
echo "Waiting for MySQL to accept connections..."
until mysqladmin ping -h "127.0.0.1" --silent >/dev/null 2>&1; do
    echo "  ...still waiting for MySQL..."
    sleep 2
done
echo "✅ MySQL is up and responding."

# ---------------------------
# Create Metastore DB if missing
# ---------------------------
DB_EXISTS=$(mysql -u root -Bse "SHOW DATABASES LIKE 'metastore';")
if [ -z "$DB_EXISTS" ]; then
    echo "Metastore database does not exist. Creating..."
    mysql -u root -Bse "CREATE DATABASE metastore;"
else
    echo "Metastore database already exists."
fi

# ---------------------------
# Initialize Hive Metastore schema if no tables exist
# ---------------------------
TABLE_COUNT=$(mysql -u root -Bse "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='metastore';")
if [ "$TABLE_COUNT" -eq 0 ]; then
    echo "Initializing Hive Metastore schema..."
    mysql -u root metastore < /usr/hive/scripts/metastore/upgrade/mysql/hive-schema-4.0.0.mysql.sql
fi

# ---------------------------
# Create/Grant Hive user
# ---------------------------
mysql -u root -Bse "
CREATE USER IF NOT EXISTS 'hive'@'localhost' IDENTIFIED BY 'password';
REVOKE ALL PRIVILEGES, GRANT OPTION FROM 'hive'@'localhost';
GRANT ALL PRIVILEGES ON metastore.* TO 'hive'@'localhost';
FLUSH PRIVILEGES;
"

# ---------------------------
# Persist previous Metastore data (if dump exists)
# ---------------------------
if [ -f /hadoop_data/dump/metastore_dump ]; then
    echo "Restoring previous metastore dump..."
    mysql metastore < /hadoop_data/dump/metastore_dump
fi

# ---------------------------
# Start Hive services
# ---------------------------
mkdir -p /usr/hive/logs

# Wait for MySQL to be ready
#until mysqladmin ping -h "localhost" --silent; do
#  echo "Waiting for MySQL..."
#  sleep 2
#done


echo "Starting Hive Metastore..."
nohup hive --service metastore > /usr/hive/logs/metastore.log 2>&1 &

# Wait until metastore responds on port 9083
echo "Waiting for Hive Metastore to be ready..."
for i in {1..30}; do
  if nc -z localhost 9083; then
    echo "Hive Metastore is up!"
    break
  fi
  echo "Metastore not ready yet... ($i)"
  sleep 3
done


echo "Starting HiveServer2..."
nohup hive --service hiveserver2 > /usr/hive/logs/hiveserver2.log 2>&1 &



# ---------------------------
# Load cron jobs
# ---------------------------
if [ -f /etc/cron.d/jobPersistMetaStore ]; then
    echo "Loading cron job for metastore persistence..."
    crontab /etc/cron.d/jobPersistMetaStore
    cron
else
    echo "No cron job file found at /etc/cron.d/jobPersistMetaStore"
fi

# ---------------------------
# Keep container alive
# ---------------------------
echo "Hive container initialized successfully. Keeping alive..."
wait $MYSQL_PID &
tail -f /dev/null