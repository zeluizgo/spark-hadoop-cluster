#!/bin/bash

set -e

/etc/init.d/ssh start
echo "[BOOTSTRAP] Configuring Hadoop for hostname: $(hostname -f)"
# replace token
for f in ${HADOOP_CONF_DIR}/*.xml; do
    sed -i "s/\${HOSTNAME}/$(hostname -f)/g" "$f"
done


if [[ "$HOSTNAME" == "spark-master" ]]; then
    echo "[BOOTSTRAP] Starting MASTER node"

    # Initialize HDFS only on first run
    if [ ! -d "/hadoop_data/dfs/name/current" ]; then
        echo "[BOOTSTRAP] Formatting NameNode..."
        hdfs namenode -format -forcee -nonInteractive
    else
        echo "[BOOTSTRAP] NameNode already formatted."
    fi

    # Start HDFS + YARN ResourceManager
    $HADOOP_HOME/sbin/start-dfs.sh

    echo "[BOOTSTRAP] Also starting DataNode on master node"
    # Same command you use on workers
    nohup java -cp "${HADOOP_HOME}/etc/hadoop:${HADOOP_HOME}/share/hadoop/common/*:${HADOOP_HOME}/share/hadoop/common/lib/*:${HADOOP_HOME}/share/hadoop/hdfs/*:${HADOOP_HOME}/share/hadoop/thirdparty/*" \
         -Dproc_datanode \
         -Dhadoop.log.dir=${HADOOP_HOME}/logs \
         -Dhadoop.log.file=hadoop-root-datanode-$(hostname).log \
         -Dhadoop.root.logger=INFO,console \
         org.apache.hadoop.hdfs.server.datanode.DataNode \
         > ${HADOOP_HOME}/logs/datanode-master.log 2>&1 &

    $HADOOP_HOME/sbin/start-yarn.sh

    sleep 8

    # Start Spark Master (only because you want WebUI — YARN will be used for jobs)
    $SPARK_HOME/sbin/start-master.sh

    sleep 10

    # Cria diretórios essenciais no HDFS
    hdfs dfs -mkdir -p /datasets /datasets_processed /spark-logs /shared-libs 2>/dev/null || true
    hdfs dfs -chmod 1777 /spark-logs 2>/dev/null || true
    hdfs dfs -put -f $SPARK_HOME/jars/* /shared-libs/ 2>/dev/null || true
    hdfs dfs -chown -R yarn:hadoop /shared-libs 2>/dev/null || true

    # Sai do Safe Mode (necessário após o primeiro start-dfs.sh)
    hdfs dfsadmin -safemode leave 2>/dev/null || true

    echo "[BOOTSTRAP] Waiting for HDFS to become fully ready..."
    until hdfs dfsadmin -report | grep "Live datanodes" | grep -q "[1-9]"; do
        echo "Waiting for at least one live DataNode..."
        sleep 5
    done
    echo "HDFS looks alive → proceeding"

    echo "[BOOTSTRAP] Ensuring spark event log directory exists..."
    EVENTLOG_DIR="hdfs://spark-master:9000/spark-logs"
    hdfs dfs -mkdir -p "$EVENTLOG_DIR" || true
    hdfs dfs -chmod 1777 "$EVENTLOG_DIR" || true

    echo "[BOOTSTRAP] Starting Spark History Server in foreground..."
    # We run it in foreground so the container stays alive because of it
    # (you can still access other UIs)
    
    # Force Spark web UIs (including HistoryServer) to listen on all network interfaces
    export SPARK_LOCAL_IP=0.0.0.0

    exec $SPARK_HOME/bin/spark-class org.apache.spark.deploy.history.HistoryServer \
        > "$SPARK_HOME/logs/history-server.log" 2>&1

    echo "MASTER totalmente pronto!"
    echo "   NameNode UI      → http://$(hostname -I | awk '{print $1}'):9870"
    echo "   YARN UI          → http://$(hostname -I | awk '{print $1}'):8088"
    echo "   Spark Master UI  → http://$(hostname -I | awk '{print $1}'):8080"
    echo "   History Server   → http://$(hostname -I | awk '{print $1}'):18080"

else
    echo "[BOOTSTRAP] Starting WORKER node ($HOSTNAME)"

    # YARN NodeManager
    $HADOOP_HOME/bin/yarn --daemon start nodemanager

    # DataNode direto na JVM — a ÚNICA forma estável no Raspberry Pi + Hadoop 3.4.0
    echo "[BOOTSTRAP] Starting DataNode (JVM direta — solução definitiva)"
    exec java -cp "${HADOOP_HOME}/etc/hadoop:${HADOOP_HOME}/share/hadoop/common/*:${HADOOP_HOME}/share/hadoop/common/lib/*:${HADOOP_HOME}/share/hadoop/hdfs/*:${HADOOP_HOME}/share/hadoop/thirdparty/*" \
         -Dproc_datanode \
         -Dhadoop.log.dir=${HADOOP_HOME}/logs \
         -Dhadoop.log.file=hadoop-root-datanode-$(hostname).log \
         -Dhadoop.root.logger=INFO,console \
         org.apache.hadoop.hdfs.server.datanode.DataNode
fi

# Keep container alive
tail -f /dev/null
