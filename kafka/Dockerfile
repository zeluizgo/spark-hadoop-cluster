FROM arm64v8/openjdk:8-jre-slim

# Variaveis de ambiente do Hadoop
ENV HADOOP_VERSION 3.3.6
ENV HADOOP_MINOR_VERSION 3
ENV HADOOP_HOME /usr/hadoop-$HADOOP_VERSION
ENV HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop

# Variaveis de ambiente do Hive
ENV HIVE_VERSION 3.1.3
ENV HIVE_HOME=/usr/hive
ENV HIVE_PORT 10000

# Variaveis de ambiente do Scala
ENV SCALA_VERSION 2.13.0
ENV SCALA_HOME=/usr/scala
ENV PATH=$PATH:$SCALA_HOME/bin

# Variaveis de ambiente do Zookeeper
ENV ZOOKEEPER_VERSION 3.6.1
ENV ZOOKEEPER_HOME /usr/apache-zookeeper-$ZOOKEEPER_VERSION-bin

# Variaveis de ambiente do Kafka
ENV SCALA_KAFKA_VERSION 2.13-3.4.1
ENV KAFKA_VERSION 3.4.1
ENV KAFKA_HOME=/usr/kafka

# Classpath para localizar os jars com as classes necessarias
ENV CLASSPATH=$HIVE_HOME/lib:$SCALA_HOME/lib:$KAFKA_HOME/lib

# Variaveis de ambiente do Spark
ENV SPARK_VERSION 3.4.1
ENV SPARK_HOME /usr/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_MINOR_VERSION}
ENV SPARK_DIST_CLASSPATH="$HADOOP_HOME/etc/hadoop/*:$HADOOP_HOME/share/hadoop/common/lib/*:$HADOOP_HOME/share/hadoop/common/*:$HADOOP_HOME/share/hadoop/hdfs/*:$HADOOP_HOME/share/hadoop/hdfs/lib/*:$HADOOP_HOME/share/hadoop/hdfs/*:$HADOOP_HOME/share/hadoop/yarn/lib/*:$HADOOP_HOME/share/hadoop/yarn/*:$HADOOP_HOME/share/hadoop/mapreduce/lib/*:$HADOOP_HOME/share/hadoop/mapreduce/*:$HADOOP_HOME/share/hadoop/tools/lib/*"

# Configuracoes do pyspark
ENV PYSPARK_PYTHON python3

# Usar python3 para modo cluster, e jupyter + configuracao de PYSPARK_DRIVER_PYTHON_OPTS='notebook'
# para modo interativo
ENV PYSPARK_DRIVER_PYTHON=python3
# ENV PYSPARK_DRIVER_PYTHON=jupyter
# ENV PYSPARK_DRIVER_PYTHON_OPTS='notebook'

ENV SPARK_MASTER_WEBUI_PORT 8080
ENV SPARK_MASTER_LOG /spark/logs
ENV SPARK_MASTER_HOST spark-master
ENV SPARK_MASTER_PORT 7077

ENV SPARK_WORKER_WEBUI_PORT 8081
ENV SPARK_MASTER spark://$SPARK_MASTER_HOST:$SPARK_MASTER_PORT
ENV SPARK_WORKER_LOG /spark/logs
ENV YARN_CONF_DIR $HADOOP_CONF_DIR

ENV HDFS_DATANODE_USER root
ENV HADOOP_SECURE_DN_USER root 
ENV HDFS_NAMENODE_USER root 
ENV HDFS_SECONDARYNAMENODE_USER root 
ENV YARN_RESOURCEMANAGER_USER root
ENV YARN_NODEMANAGER_USER root
#ENV JAVA_HOME /usr/lib/jvm/adoptopenjdk-8-hotspot-arm64

# Adicao de valores aos paths abaixo para que os componentes os localizem
ENV PYTHONPATH $SPARK_HOME/python:$SPARK_HOME/python/lib/py4j-0.10.7-src.zip:/usr/bin/python3
ENV PATH $PATH:$JAVA_HOME/bin:$HADOOP_HOME/bin:$SPARK_HOME/bin:$SPARK_HOME/python:$SPARK_HOME/python/lib/py4j-0.10.7-src.zip:$PYTHONPATH:$HIVE_HOME/bin:$KAFKA_HOME/bin:$SCALA_HOME/bin

# Install dependencies
RUN apt-get update && apt-get install -y curl gnupg2 ca-certificates

# Import the AdoptOpenJDK GPG key
#RUN curl -fsSL https://adoptopenjdk.jfrog.io/adoptopenjdk/api/gpg/key/public | gpg --dearmor --yes -o /usr/share/keyrings/adoptopenjdk-archive-keyring.gpg

# Add AdoptOpenJDK repository
#RUN echo "deb [signed-by=/usr/share/keyrings/adoptopenjdk-archive-keyring.gpg] https://adoptopenjdk.jfrog.io/adoptopenjdk/deb bullseye main" |    tee /etc/apt/sources.list.d/adoptopenjdk.list > /dev/null

# Install Java 8 (OpenJDK 8)
#RUN apt-get update && apt-get install -y adoptopenjdk-8-hotspot

# Install Python 3.11
RUN apt-get update && apt-get install -y --no-install-recommends python3 python3-pip python3-dev gcc
#RUN apt-get install -y python3.11 python3-pip \
#    ln -s /usr/bin/python3.11 /usr/bin/python \
#    ln -s /usr/bin/python3.11 /usr/bin/python3 

COPY /config/jupyter/requirements.txt /

RUN python3 -m pip install -r requirements.txt  --upgrade \
    && python3 -m pip install dask[bag] --upgrade \
    && python3 -m pip install --upgrade toree \
    && python3 -m pip install bash_kernel
    
# Install MySQL 8.0
RUN apt-get update && apt-get install -y \
    default-mysql-server wget \
    && rm -rf /var/lib/apt/lists/*
#gcc

# Configure MySQL
RUN mkdir -p /etc/mysql/mysql.conf.d ; touch /etc/mysql/mysql.conf.d/mysqld.cnf ; mkdir -p /var/run/mysqld ;
RUN sed -i 's/^bind-address/#bind-address/' /etc/mysql/mysql.conf.d/mysqld.cnf \
    && sed -i '/\[mysqld\]/a datadir = /var/lib/mysql' /etc/mysql/mysql.conf.d/mysqld.cnf \
    && sed -i '/\[mysqld\]/a socket = /var/run/mysqld/mysqld.sock' /etc/mysql/mysql.conf.d/mysqld.cnf

# Update ownership and permissions
RUN chown -R mysql:mysql /var/lib/mysql \
    && chown -R mysql:mysql /var/run/mysqld \
    && chmod 777 /var/run/mysqld

# Install ssh
RUN apt-get update && apt-get install -y --no-install-recommends ssh openssh-server

# Keys dos nodes. Necessarias para se comunicarem por SSH
RUN ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa && \
    cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys && \
    chmod 600 ~/.ssh/authorized_keys
COPY /config/config /root/.ssh
RUN chmod 600 /root/.ssh/config

    # Hadoop
RUN wget \
    "http://archive.apache.org/dist/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz" \
    && tar zvxf hadoop-${HADOOP_VERSION}.tar.gz -C /usr/ \
    && rm hadoop-${HADOOP_VERSION}.tar.gz \
    && rm -rf ${HADOOP_HOME}/share/doc \
    && chown -R root:root ${HADOOP_HOME} \
    # Spark
    && wget \
    "http://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_MINOR_VERSION}.tgz" \
    && tar zvxf spark-${SPARK_VERSION}-bin-hadoop${HADOOP_MINOR_VERSION}.tgz -C /usr/ \
    && rm spark-${SPARK_VERSION}-bin-hadoop${HADOOP_MINOR_VERSION}.tgz \
    && chown -R root:root ${SPARK_HOME} \
    # Hive
    && wget \
    https://archive.apache.org/dist/hive/hive-${HIVE_VERSION}/apache-hive-${HIVE_VERSION}-bin.tar.gz \
    && tar zxvf apache-hive-${HIVE_VERSION}-bin.tar.gz \
    && rm apache-hive-${HIVE_VERSION}-bin.tar.gz \
    && mv apache-hive-${HIVE_VERSION}-bin ${HIVE_HOME} \
    && cp ${HIVE_HOME}/conf/hive-env.sh.template ${HIVE_HOME}/conf/hive-env.sh \
    && echo "export HADOOP_HOME=/usr/hadoop-${HADOOP_VERSION}/" >> ${HIVE_HOME}/conf/hive-env.sh \
    # Configurando o conector do metastore do Hive
    && ln -s /usr/share/java/mariadb-java-client.jar ${HIVE_HOME}/lib/mariadb-java-client.jar \
    # Criando diretório para jars externos do Hive e baixando suporte a parquet
    && wget https://repo1.maven.org/maven2/com/twitter/parquet-avro/1.2.5/parquet-avro-1.2.5.jar -P /usr/hive/aux_jars/ \
    && wget https://repo1.maven.org/maven2/com/mysql/mysql-connector-j/8.0.33/mysql-connector-j-8.0.33.jar -P /usr/hive/lib/ \
    # Zookeeper
    && wget \
    https://archive.apache.org/dist/zookeeper/zookeeper-${ZOOKEEPER_VERSION}/apache-zookeeper-${ZOOKEEPER_VERSION}-bin.tar.gz\
    && tar -zvxf apache-zookeeper-${ZOOKEEPER_VERSION}-bin.tar.gz \
    && rm apache-zookeeper-${ZOOKEEPER_VERSION}-bin.tar.gz \
    && mv apache-zookeeper-${ZOOKEEPER_VERSION}-bin /usr/apache-zookeeper-${ZOOKEEPER_VERSION}-bin \
    && mkdir /var/lib/zookeeper \
    # Scala
    && wget \
    https://downloads.lightbend.com/scala/${SCALA_VERSION}/scala-${SCALA_VERSION}.tgz \
    && tar -zvxf scala-${SCALA_VERSION}.tgz \
    && rm scala-${SCALA_VERSION}.tgz \
    && mv /scala-${SCALA_VERSION} /usr/scala \
    # Kafka
    && wget \
    https://archive.apache.org/dist/kafka/${KAFKA_VERSION}/kafka_${SCALA_KAFKA_VERSION}.tgz \
    && tar -zvxf kafka_${SCALA_KAFKA_VERSION}.tgz \
    && rm kafka_${SCALA_KAFKA_VERSION}.tgz \
    && mv kafka_${SCALA_KAFKA_VERSION} /usr/kafka \
    # Configurando o JAVA_HOME para os processos localizarem a instalação do Java
    && echo "export JAVA_HOME=${JAVA_HOME}" >> /etc/environment

COPY config/hive/*.xml $HIVE_HOME/conf/
COPY config/hive/*.xml $SPARK_HOME/conf/

COPY config/hadoop/masters $HADOOP_HOME/conf/
COPY config/hadoop/slaves $HADOOP_HOME/conf/

# Todos os arquivos de configuracao que devem ser copiados para dentro do
# container estao aqui
COPY config/spark ${SPARK_HOME}/conf/
COPY config/hadoop/*.xml /usr/hadoop-${HADOOP_VERSION}/etc/hadoop/
COPY config/scripts /
COPY config/zookeeper ${ZOOKEEPER_HOME}/conf/
COPY config/kafka ${KAFKA_HOME}/config

# Portas 10000:10002 relativas ao Hiveserver2
# Portas 2181 2888 e 3888 relativas ao Zookeper, 9092 ao Kafka, 9999 webui do Hiveserver
EXPOSE 8042 9870 18080 10015
EXPOSE 9000 4040 8020 22 9083 10000 10001 10002 2181 2888 3888 9092 9999 3306
EXPOSE 8080 7077 6066 7001 8030 8031 8032 2181 2888 3888 8088 8888 8081

# Algumas configuracoes adicionais e inicio de alguns servicoes que devem ser feitos em
# tempo de execucao estao presentes no script bootstrap.
# Este cuidará de colocar alguns datasets exemplo dentro do HDFS, bem como de iniciar 
# servicos como HDFS (formatando Namenode), iniciando o Hive, definindo o ID do 
# Zookeeper para que suas diferentes instâncias possam se ver e iniciando este servico.
# O comando ENTRYPOINT define que este script será executado quando os containeres
# iniciarem.
ENTRYPOINT ["/bin/bash", "bootstrap.sh"]
