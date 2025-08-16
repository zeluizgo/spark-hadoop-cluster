#!/bin/bash

# Este trecho rodará independente de termos um container master ou
# worker. Necesário para funcionamento do HDFS e para comunicação
# dos containers/nodes.
/etc/init.d/ssh start

# Abaixo temos o trecho que rodará apenas no master.
if [[ $HOSTNAME = spark-master ]]; then

    if [ -d "/hadoop_data/data/nameNode" ]
    then
        echo "nameNode hadoop directory already exists." 
        # here could get namenode out of safemode...lol
    else
        # Formatamos o namenode
        hdfs namenode -format
    fi

    # Iniciamos os serviços
    $HADOOP_HOME/sbin/start-dfs.sh
    $HADOOP_HOME/sbin/start-yarn.sh
    $SPARK_HOME/sbin/start-master.sh

    # Criação de diretórios no ambiente distribuído do HDFS
    hdfs dfs -mkdir /datasets
    hdfs dfs -mkdir /datasets_processed
    hdfs dfs -mkdir /spark-logs
    hdfs dfs -mkdir /shared-libs

    #$SPARK_HOME/sbin/start-history-server.sh
    $SPARK_HOME/bin/spark-class org.apache.spark.deploy.history.HistoryServer

# E abaixo temos o trecho que rodará nos workers
else
    # Configs de HDFS nos dataNodes (workers)
    $HADOOP_HOME/sbin/hadoop-daemon.sh start datanode &
    $HADOOP_HOME/bin/yarn nodemanager &
    
    $SPARK_HOME/sbin/start-worker.sh spark://$SPARK_MASTER_HOST:$SPARK_MASTER_PORT

fi

while :; do sleep 2073600; done
