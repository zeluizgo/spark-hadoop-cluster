#!/bin/bash

# ---------------------------
# Start SSH for Hadoop communication
# ---------------------------
/etc/init.d/ssh start

# ---------------------------
# Start MySQL (MariaDB)
# ---------------------------
service mariadb start

# Wait until MySQL is ready
until mysqladmin ping -u root --silent; do
    echo "Waiting for MySQL..."
    sleep 2
done

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
    mysql -u root metastore < /usr/hive/scripts/metastore/upgrade/mysql/hive-schema-3.1.0.mysql.sql
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
until mysqladmin ping -h "localhost" --silent; do
  echo "Waiting for MySQL..."
  sleep 2
done


echo "Starting Hive Metastore..."
nohup hive --service metastore > /usr/hive/logs/metastore.log 2>&1 &

# Wait a few seconds for Metastore to be fully ready
sleep 5

echo "Starting HiveServer2..."
nohup hive --service hiveserver2 > /usr/hive/logs/hiveserver2.log 2>&1 &

# ---------------------------
# Load cron jobs
# ---------------------------
crontab /etc/cron.d/jobPersistMetaStore
cron

# ---------------------------
# Keep container alive
# ---------------------------
tail -f /dev/null