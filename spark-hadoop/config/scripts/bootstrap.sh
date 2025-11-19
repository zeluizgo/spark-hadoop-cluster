#!/bin/bash

set -e

/etc/init.d/ssh start

if [[ "$HOSTNAME" == "spark-master" ]]; then
    echo "[BOOTSTRAP] Starting MASTER node"

    # Initialize HDFS only on first run
    if [ ! -d "/hadoop_data/data/nameNode/current" ]; then
        echo "[BOOTSTRAP] Formatting NameNode..."
        hdfs namenode -format -force
    else
        echo "[BOOTSTRAP] NameNode already formatted."
    fi

    # Start HDFS + YARN ResourceManager
    $HADOOP_HOME/sbin/start-dfs.sh
    $HADOOP_HOME/sbin/start-yarn.sh

    sleep 5

    # Start Spark Master (only because you want WebUI — YARN will be used for jobs)
    $SPARK_HOME/sbin/start-master.sh

    sleep 10

    # Create required HDFS directories
    hdfs dfs -mkdir -p /datasets \
                     /datasets_processed \
                     /spark-logs \
                     /shared-libs

    # Upload Spark libraries for YARN
    hdfs dfs -put -f $SPARK_HOME/jars/* /shared-libs/

    # Start Spark History Server
   # FORMA DIRETA E 100% CONFIÁVEL – funciona em qualquer Spark 3.x/4.x (2025)
    echo "[BOOTSTRAP] Starting Spark History Server (direct Java call)..."

    # Diretório onde ficam os event-logs (mude se quiser local ou outro path no HDFS)
    EVENT_LOG_DIR="hdfs://spark-master:9000/spark-logs"

    # Cria o diretório no HDFS se não existir
    hdfs dfs -mkdir -p $EVENT_LOG_DIR 2>/dev/null || true
    hdfs dfs -chmod 777 $EVENT_LOG_DIR 2>/dev/null || true

    # Inicia o History Server direto na JVM (sem script, sem mistério)
    $SPARK_HOME/bin/spark-class org.apache.spark.deploy.history.HistoryServer \
        --properties-file $SPARK_HOME/conf/spark-defaults.conf \
        1 \
        $EVENT_LOG_DIR \
        > $SPARK_HOME/logs/history-server.out 2>&1 &

    # Pequeno delay + confirmação visual
    sleep 8
    if pgrep -f HistoryServer > /dev/null; then
        echo "History Server rodando → http://$(hostname -I | awk '{print $1}'):18080"
    else
        echo "FALHOU → últimas linhas do log:"
        tail -20 $SPARK_HOME/logs/history-server.out
    fi

else
    echo "[BOOTSTRAP] Starting WORKER node"

    # Start YARN NodeManager
    $HADOOP_HOME/bin/yarn nodemanager &

    # Start HDFS DataNode
    $HADOOP_HOME/sbin/hadoop-daemon.sh start datanode &

    # DO NOT start Spark Worker (Spark is running on YARN!!)
fi

# Keep container alive
tail -f /dev/null
