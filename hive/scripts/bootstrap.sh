#!/bin/bash

# Este trecho rodará independente de termos um container master ou
# worker. Necesário para funcionamento do HDFS e para comunicação
# dos containers/nodes.
/etc/init.d/ssh start

# Abaixo temos o trecho que rodará apenas no master.
    
# Formatamos o namenode
#hdfs namenode -format

# Inicio do mysql - metastore o Hive
service mariadb start
#mysqld --user=mysql

# Configs de Hive, configurando o metastore, definindo senha, etc...
mysql -u root -Bse \
"CREATE DATABASE metastore; \
USE metastore; \
SOURCE /usr/hive/scripts/metastore/upgrade/mysql/hive-schema-3.1.0.mysql.sql; \
CREATE USER 'hive'@'localhost' IDENTIFIED BY 'password'; \
REVOKE ALL PRIVILEGES, GRANT OPTION FROM 'hive'@'localhost'; \
GRANT ALL PRIVILEGES ON metastore.* TO 'hive'@'localhost'; \
FLUSH PRIVILEGES; quit;"

#Persistindo dados anteriores do metastore
mysql metastore < /hadoop_data/dump/metastore_dump

# Inicio dos serviços do Hive. Nao recomendado: Redirecionamos
# os outputs para uma localização inexistente para que as linhas
# não bloqueiem o shell
nohup hive --service metastore > /dev/null 2>&1 &
nohup hive --service hiveserver2 > /dev/null 2>&1 &

while :; do sleep 2073600; done
