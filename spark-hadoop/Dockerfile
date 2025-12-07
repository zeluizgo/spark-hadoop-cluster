FROM --platform=linux/arm64 eclipse-temurin:17-jdk-jammy


# ---------- Versions ----------
ENV SCALA_VERSION=2.13.16
ENV HADOOP_VERSION=3.4.0
ENV HADOOP_MINOR_VERSION=3
ENV SPARK_VERSION=4.0.1


# ---------- Core Paths ----------
#ENV JAVA_HOME=/usr/local/openjdk-17
ENV JAVA_HOME=/opt/java/openjdk
ENV SCALA_HOME=/usr/scala
ENV HADOOP_HOME=/usr/hadoop-${HADOOP_VERSION}
ENV HADOOP_CONF_DIR=${HADOOP_HOME}/etc/hadoop
ENV SPARK_HOME=/usr/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_MINOR_VERSION}
ENV SPARK_CONF_DIR=${SPARK_HOME}/conf
ENV CLASSPATH=${SPARK_HOME}/jars/*
ENV PATH=$PATH:$JAVA_HOME/bin:$HADOOP_HOME/bin:$SPARK_HOME/bin:$SCALA_HOME/bin
ENV PYTHONPATH=$SPARK_HOME/python:$SPARK_HOME/python/lib/py4j-0.10.9.7-src.zip


# ---------- Spark Environment ----------
ENV SPARK_MASTER_WEBUI_PORT=8080
ENV SPARK_MASTER_HOST=spark-master
ENV SPARK_MASTER_PORT=7077
ENV SPARK_MASTER_URL=spark://$SPARK_MASTER_HOST:$SPARK_MASTER_PORT
ENV SPARK_MASTER=$SPARK_MASTER_URL
ENV PYSPARK_PYTHON=python3
ENV PYSPARK_DRIVER_PYTHON=python3

#ENV SPARK_MASTER_LOG=/spark/logs
#ENV SPARK_WORKER_WEBUI_PORT=8081
#ENV SPARK_WORKER_LOG=/spark/logs


# ---------- Hadoop/HDFS Users ----------
ENV HDFS_DATANODE_USER=root
ENV HDFS_DATANODE_SECURE_USER=root
ENV HDFS_NAMENODE_USER=root
ENV HDFS_SECONDARYNAMENODE_USER=root
ENV YARN_RESOURCEMANAGER_USER=root
ENV YARN_NODEMANAGER_USER=root

# ---------- JVM Options ----------
# JVM Options (add-opens para Java 17)
ENV HADOOP_OPTS="-XX:+IgnoreUnrecognizedVMOptions \
--add-opens=java.base/java.lang=ALL-UNNAMED \
--add-opens=java.base/java.lang.reflect=ALL-UNNAMED \
--add-opens=java.base/java.io=ALL-UNNAMED \
--add-opens=java.base/java.net=ALL-UNNAMED \
--add-opens=java.base/java.nio=ALL-UNNAMED \
--add-opens=java.base/sun.nio.ch=ALL-UNNAMED \
--add-opens=java.base/java.util=ALL-UNNAMED \
--add-opens=java.security.jgss/sun.security.krb5=ALL-UNNAMED"

# THIS IS THE MAGIC — THESE 2 LINES FORCE THE JVM OPTIONS ON EXECUTORS AND DRIVER
# YARN ONLY RESPECTS THESE VARIABLES 100% OF THE TIME
ENV SPARK_EXECUTOR_JAVA_OPTS="--add-opens=java.base/java.lang.invoke=ALL-UNNAMED --add-opens=java.base/java.util=ALL-UNNAMED --add-opens=java.base/java.nio=ALL-UNNAMED --add-opens=java.base/sun.nio.ch=ALL-UNNAMED --add-opens=java.base/java.lang=ALL-UNNAMED"
ENV SPARK_DRIVER_JAVA_OPTS="--add-opens=java.base/java.lang.invoke=ALL-UNNAMED --add-opens=java.base/java.util=ALL-UNNAMED --add-opens=java.base/java.nio=ALL-UNNAMED --add-opens=java.base/sun.nio.ch=ALL-UNNAMED --add-opens=java.base/java.lang=ALL-UNNAMED"


# ---------- Dependencies ----------
RUN apt-get update && \
    apt-get install -y curl gnupg2 ca-certificates ssh openssh-server wget rsync python3 python3-pip python3-dev gcc sudo && \ 
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

# ---------- Hadoop, Spark ----------
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
    chown -R root:root ${SPARK_HOME} 

# ---------- CRITICAL FIX: Create config dir BEFORE copying configs ----------
RUN mkdir -p ${HADOOP_CONF_DIR} ${SPARK_CONF_DIR}

# ---------- Config files ----------
COPY config/hadoop/masters ${HADOOP_CONF_DIR}/
COPY config/hadoop/slaves ${HADOOP_CONF_DIR}/
COPY config/spark ${SPARK_HOME}/conf/
COPY config/hadoop/*.xml ${HADOOP_CONF_DIR}/
COPY config/scripts /

# Java/Hadoop env fixes
RUN echo "export JAVA_HOME=${JAVA_HOME}" >> ${HADOOP_CONF_DIR}/hadoop-env.sh && \
    echo "export HDFS_JOURNALNODE_USER=root" >> ${HADOOP_CONF_DIR}/hadoop-env.sh && \
    echo "export JAVA_HOME=${JAVA_HOME}" >> ${HADOOP_CONF_DIR}/yarn-env.sh && \
    echo "export JAVA_HOME=${JAVA_HOME}" >> /etc/environment \
    # FIX: Adicione env vars de usuário no hadoop-env.sh (para root)
    echo "export HDFS_NAMENODE_USER=root" >> ${HADOOP_CONF_DIR}/hadoop-env.sh && \
    echo "export HDFS_DATANODE_USER=root" >> ${HADOOP_CONF_DIR}/hadoop-env.sh && \
    echo "export HDFS_SECONDARYNAMENODE_USER=root" >> ${HADOOP_CONF_DIR}/hadoop-env.sh && \
    echo "export HADOOP_SECURE_DN_USER=root" >> ${HADOOP_CONF_DIR}/hadoop-env.sh && \
    echo "export YARN_RESOURCEMANAGER_USER=root" >> ${HADOOP_CONF_DIR}/yarn-env.sh && \
    echo "export YARN_NODEMANAGER_USER=root" >> ${HADOOP_CONF_DIR}/yarn-env.sh

# Add-opens patches
#RUN sed -i '/^# *export HADOOP_OPTS=/a export HADOOP_OPTS="$HADOOP_OPTS --add-opens java.base\/java.lang=ALL-UNNAMED"' \
#      $HADOOP_CONF_DIR/hadoop-env.sh && \
#    sed -i '/^# *export YARN_RESOURCEMANAGER_OPTS=/a export YARN_RESOURCEMANAGER_OPTS="$YARN_RESOURCEMANAGER_OPTS --add-opens java.base\/java.lang=ALL-UNNAMED"' \
#      $HADOOP_CONF_DIR/yarn-env.sh

# in Dockerfile (or run inside container)
RUN sed -i '/^# *export YARN_RESOURCEMANAGER_OPTS=/a export YARN_RESOURCEMANAGER_OPTS="$YARN_RESOURCEMANAGER_OPTS --add-opens=java.base\/java.lang=ALL-UNNAMED --add-opens=java.base\/java.lang.reflect=ALL-UNNAMED --add-opens=java.base\/java.lang.invoke=ALL-UNNAMED --add-opens=java.base\/java.io=ALL-UNNAMED --add-opens=java.base\/java.net=ALL-UNNAMED --add-opens=java.base\/java.nio=ALL-UNNAMED --add-opens=java.base\/sun.nio.ch=ALL-UNNAMED --add-opens=java.base\/java.util=ALL-UNNAMED"' \
    ${HADOOP_CONF_DIR}/yarn-env.sh

ENV JAVA_TOOL_OPTIONS="--add-opens=java.base/java.lang=ALL-UNNAMED --add-opens=java.base/java.lang.reflect=ALL-UNNAMED --add-opens=java.base/java.lang.invoke=ALL-UNNAMED --add-opens=java.base/java.io=ALL-UNNAMED --add-opens=java.base/java.net=ALL-UNNAMED --add-opens=java.base/java.nio=ALL-UNNAMED --add-opens=java.base/sun.nio.ch=ALL-UNNAMED --add-opens=java.base/java.util=ALL-UNNAMED"

# Expose ports
EXPOSE 8042 9870 18080 9000 4040 8020 22 8080 7077 8081 8088 6066 8030 8031 8032

# Clean up
RUN apt-get remove -y wget unzip && apt-get autoremove -y && apt-get clean

ENTRYPOINT ["/bin/bash", "bootstrap.sh"]