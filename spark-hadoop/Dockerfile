FROM --platform=linux/arm64 eclipse-temurin:17-jdk-jammy


# ---------- Versions ----------
ENV SCALA_VERSION=2.12.18
ENV HADOOP_VERSION=3.3.5
ENV HADOOP_MINOR_VERSION=3
ENV HIVE_VERSION=3.1.3
ENV SPARK_VERSION=3.5.0


# ---------- Core Paths ----------
#ENV JAVA_HOME=/usr/local/openjdk-17
ENV JAVA_HOME=/opt/java/openjdk
ENV SCALA_HOME=/usr/scala
ENV HADOOP_HOME=/usr/hadoop-${HADOOP_VERSION}
ENV HADOOP_CONF_DIR=${HADOOP_HOME}/etc/hadoop
ENV HIVE_HOME=/usr/hive
ENV SPARK_HOME=/usr/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_MINOR_VERSION}
ENV SPARK_CONF_DIR=${SPARK_HOME}/conf
ENV CLASSPATH=${HIVE_HOME}/lib
ENV PATH=$PATH:$JAVA_HOME/bin:$HADOOP_HOME/bin:$SPARK_HOME/bin:$HIVE_HOME/bin:$SCALA_HOME/bin
ENV PYTHONPATH=$SPARK_HOME/python:$SPARK_HOME/python/lib/py4j-0.10.9.7-src.zip


# ---------- Spark Environment ----------
ENV SPARK_MASTER_WEBUI_PORT=8080
ENV SPARK_MASTER_HOST=spark-master
ENV SPARK_MASTER_PORT=7077
ENV SPARK_MASTER_URL=spark://$SPARK_MASTER_HOST:$SPARK_MASTER_PORT
ENV SPARK_MASTER=$SPARK_MASTER_URL
ENV SPARK_MASTER_LOG=/spark/logs
ENV SPARK_WORKER_WEBUI_PORT=8081
ENV SPARK_WORKER_LOG=/spark/logs
ENV PYSPARK_PYTHON=python3
ENV PYSPARK_DRIVER_PYTHON=python3


# ---------- Hadoop/HDFS Users ----------
ENV HDFS_DATANODE_USER=root
ENV HDFS_DATANODE_SECURE_USER=root
ENV HDFS_NAMENODE_USER=root
ENV HDFS_SECONDARYNAMENODE_USER=root
ENV YARN_RESOURCEMANAGER_USER=root
ENV YARN_NODEMANAGER_USER=root


# ---------- JVM Options ----------
ENV HADOOP_OPTS="-XX:+IgnoreUnrecognizedVMOptions -XX:-UseContainerSupport \
 --add-opens=java.base/java.lang=ALL-UNNAMED \
 --add-opens=java.base/java.lang.reflect=ALL-UNNAMED \
 --add-opens=java.base/java.io=ALL-UNNAMED \
 --add-opens=java.base/java.net=ALL-UNNAMED \
 --add-opens=java.base/java.nio=ALL-UNNAMED \
 --add-opens=java.base/sun.nio.ch=ALL-UNNAMED \
 --add-opens=java.base/java.util=ALL-UNNAMED \
 --add-opens=java.security.jgss/sun.security.krb5=ALL-UNNAMED"


# ---------- Dependencies ----------
RUN apt-get update && \
    apt-get install -y curl gnupg2 ca-certificates ssh openssh-server wget rsync python3 python3-pip python3-dev gcc && \
    apt-get clean



# ---------- Python dependencies ----------
COPY /config/jupyter/requirements.txt /
RUN python3 -m pip install --upgrade pip && \
    python3 -m pip install -r requirements.txt && \
    python3 -m pip install --upgrade dask[bag] toree bash_kernel



# ---------- SSH setup ----------
RUN mkdir -p /root/.ssh && \
    ssh-keygen -t rsa -P '' -f /root/.ssh/id_rsa && \
    cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys && \
    chmod 700 /root/.ssh && \
    chmod 600 /root/.ssh/authorized_keys
COPY /config/config /root/.ssh/config
RUN chmod 600 /root/.ssh/config



# ---------- Scala ----------
RUN wget https://downloads.lightbend.com/scala/${SCALA_VERSION}/scala-${SCALA_VERSION}.tgz && \
    tar zxvf scala-${SCALA_VERSION}.tgz -C /usr/ && \
    rm scala-${SCALA_VERSION}.tgz && \
    mv /usr/scala-${SCALA_VERSION} /usr/scala && \
    ln -s /usr/scala/bin/* /usr/bin/


# ---------- Hadoop, Spark, Hive ----------
         # Hadoop
RUN wget http://archive.apache.org/dist/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz && \
    tar zxvf hadoop-${HADOOP_VERSION}.tar.gz -C /usr/ && \
    rm hadoop-${HADOOP_VERSION}.tar.gz && \
    rm -rf ${HADOOP_HOME}/share/doc && \
    chown -R root:root ${HADOOP_HOME} && \
         # Spark
    wget http://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_MINOR_VERSION}.tgz && \
    tar zxvf spark-${SPARK_VERSION}-bin-hadoop${HADOOP_MINOR_VERSION}.tgz -C /usr/ && \
    rm spark-${SPARK_VERSION}-bin-hadoop${HADOOP_MINOR_VERSION}.tgz && \
    chown -R root:root ${SPARK_HOME} && \
        # Hive
    wget https://archive.apache.org/dist/hive/hive-${HIVE_VERSION}/apache-hive-${HIVE_VERSION}-bin.tar.gz && \
    tar zxvf apache-hive-${HIVE_VERSION}-bin.tar.gz && \
    rm apache-hive-${HIVE_VERSION}-bin.tar.gz && \
    mv apache-hive-${HIVE_VERSION}-bin ${HIVE_HOME} && \
    cp ${HIVE_HOME}/conf/hive-env.sh.template ${HIVE_HOME}/conf/hive-env.sh && \
    echo "export HADOOP_HOME=${HADOOP_HOME}" >> ${HIVE_HOME}/conf/hive-env.sh && \
    # Configurando o conector do metastore do Hive
    ln -s /usr/share/java/mariadb-java-client.jar ${HIVE_HOME}/lib/mariadb-java-client.jar && \
    # Criando diretório para jars externos do Hive e baixando suporte a parquet
    mkdir -p /usr/hive/aux_jars && \
    wget https://repo1.maven.org/maven2/com/twitter/parquet-avro/1.2.5/parquet-avro-1.2.5.jar -P /usr/hive/aux_jars/ && \
    wget https://repo1.maven.org/maven2/com/mysql/mysql-connector-j/8.0.33/mysql-connector-j-8.0.33.jar -P /usr/hive/lib/ \

    # --------- Replace Spark’s Hive 2.x jars with Hive 3.1.3 ---------
    echo "Removing Hive 2.x jars from Spark and adding Hive 3.1.3..." && \
    mkdir -p ${SPARK_HOME}/hive3-lib && \
    find ${SPARK_HOME}/jars -type f -name "hive-*.jar" -exec mv {} ${SPARK_HOME}/hive3-lib/ \; && \
    find ${SPARK_HOME}/jars -type f -name "hive-shims-*.jar" -exec mv {} ${SPARK_HOME}/hive3-lib/ \; && \
    find ${SPARK_HOME}/jars -type f -name "hive-*.jar.disabled" -delete; \
    \
    # Copy Hive 3.1.3 jars into Spark’s classpath
    cp ${HIVE_HOME}/lib/hive-*.jar ${SPARK_HOME}/jars/; \
    cp ${HIVE_HOME}/lib/libfb303*.jar ${SPARK_HOME}/jars/ || true; \
    cp ${HIVE_HOME}/lib/libthrift*.jar ${SPARK_HOME}/jars/ || true; \
    \
    # Clean permissions
    chown -R root:root ${HIVE_HOME} ${SPARK_HOME}



#ENV YARN_OPTS="-XX:+IgnoreUnrecognizedVMOptions -XX:-UseContainerSupport --add-opens=java.base/java.lang=ALL-UNNAMED --add-opens=java.base/java.lang.reflect=ALL-UNNAMED --add-opens=java.base/java.io=ALL-UNNAMED --add-opens=java.base/java.net=ALL-UNNAMED --add-opens=java.base/java.nio=ALL-UNNAMED --add-opens=java.base/sun.nio.ch=ALL-UNNAMED --add-opens=java.base/java.util=ALL-UNNAMED --add-opens=java.security.jgss/sun.security.krb5=ALL-UNNAMED"

#ENV YARN_RESOURCEMANAGER_OPTS="--add-opens java.base/java.lang=ALL-UNNAMED"

#ENV HADOOP_CONF_DIR=/opt/hadoop/etc/hadoop

#RUN mkdir -p $HADOOP_CONF_DIR \
#    cp ${HADOOP_HOME}/etc/hadoop $HADOOP_CONF_DIR

ENV HIVE_CONF_DIR=/opt/hive/conf

# ---------- Apply add-opens patches directly ----------
#RUN sed -i '/^# *export HADOOP_OPTS=/a \
#export HADOOP_OPTS="$HADOOP_OPTS --add-opens java.base\/java.lang=ALL-UNNAMED"' \
#      $HADOOP_CONF_DIR/hadoop-env.sh && \
#    sed -i '/^# *export YARN_RESOURCEMANAGER_OPTS=/a \
#export YARN_RESOURCEMANAGER_OPTS="$YARN_RESOURCEMANAGER_OPTS --add-opens java.base\/java.lang=ALL-UNNAMED"' \
#      $HADOOP_CONF_DIR/yarn-env.sh

# ... your existing content until the config files section ...

# ---------- Config files ----------
COPY config/hive/*.xml ${SPARK_HOME}/conf/
COPY config/hive/*.xml ${HIVE_HOME}/conf/
COPY config/hadoop/masters ${HADOOP_CONF_DIR}/
COPY config/hadoop/slaves ${HADOOP_CONF_DIR}/
COPY config/spark ${SPARK_HOME}/conf/
COPY config/hadoop/*.xml ${HADOOP_CONF_DIR}/
COPY config/scripts /

RUN mkdir -p /tmp/hive-conf
RUN mkdir -p /opt/hive/conf

COPY config/hive/*.xml /tmp/hive-conf
COPY config/hive/*.xml /opt/hive/conf

# Set environment variables
ENV HIVE_CONF_DIR=/opt/hive/conf

# ⭐ REMOVE these lines that cause problems:
# RUN mkdir -p /etc/java-17-openjdk && \
#     echo "-Dhive.conf.dir=/opt/hive/conf" >> /etc/java-17-openjdk/java.conf && ...
# RUN echo 'export JAVA_TOOL_OPTIONS=...' >> /etc/profile && ...

# ✅ INSTEAD: Ensure JAVA_HOME is set in Hadoop's env files
RUN echo "export JAVA_HOME=${JAVA_HOME}" >> ${HADOOP_CONF_DIR}/hadoop-env.sh && \
    echo "export HDFS_JOURNALNODE_USER=root" >> ${HADOOP_CONF_DIR}/hadoop-env.sh && \
    echo "export JAVA_HOME=${JAVA_HOME}" >> ${HADOOP_CONF_DIR}/yarn-env.sh

# ✅ Also ensure it's in the global environment for all processes
RUN echo "export JAVA_HOME=${JAVA_HOME}" >> /etc/environment

# ---------- Apply add-opens patches directly ----------
RUN sed -i '/^# *export HADOOP_OPTS=/a \
export HADOOP_OPTS="$HADOOP_OPTS --add-opens java.base\/java.lang=ALL-UNNAMED"' \
      $HADOOP_CONF_DIR/hadoop-env.sh && \
    sed -i '/^# *export YARN_RESOURCEMANAGER_OPTS=/a \
export YARN_RESOURCEMANAGER_OPTS="$YARN_RESOURCEMANAGER_OPTS --add-opens java.base\/java.lang=ALL-UNNAMED"' \
      $HADOOP_CONF_DIR/yarn-env.sh

# Expose ports
EXPOSE 8042 9870 18080 9000 4040 8020 22 8080 7077 8081 8088 6066 7001 8030 8031 8032 2181 2888 3888 10000

# Clean up
RUN apt-get remove -y wget unzip && apt-get autoremove -y && apt-get clean

ENTRYPOINT ["/bin/bash", "bootstrap.sh"]