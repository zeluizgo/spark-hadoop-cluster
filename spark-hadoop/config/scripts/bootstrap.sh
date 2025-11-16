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
    echo "[BOOTSTRAP] Starting Spark History Server..."
    $SPARK_HOME/sbin/start-history-server.sh &

else
    echo "[BOOTSTRAP] Starting WORKER node"
    echo "[BOOTSTRAP] Starting WORKER node - 📂 Configuration directories:"
    echo "  [BOOTSTRAP] Starting WORKER node - HIVE_CONF_DIR=$HIVE_CONF_DIR"
    echo "  [BOOTSTRAP] Starting WORKER node - HIVE_HOME=$HIVE_HOME"

    # Verify file exists
    if [ -f "/opt/hive/conf/hive-site.xml" ]; then
        echo "[BOOTSTRAP] Starting WORKER node - ✅ Verified: /opt/hive/conf/hive-site.xml exists"
    else
        echo "[BOOTSTRAP] Starting WORKER node - ❌ ERROR: /opt/hive/conf/hive-site.xml NOT found!"
    fi

    # Start YARN NodeManager
    $HADOOP_HOME/bin/yarn nodemanager &

    # Start HDFS DataNode
    $HADOOP_HOME/sbin/hadoop-daemon.sh start datanode &

    # DO NOT start Spark Worker (Spark is running on YARN!!)
fi

# Keep container alive
tail -f /dev/null
