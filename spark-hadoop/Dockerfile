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
# Classpath para localizar os jars com as classes necessarias
ENV CLASSPATH=$HIVE_HOME/lib

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

# Adicao de valores aos paths abaixo para que os componentes os localizem
ENV PYTHONPATH $SPARK_HOME/python:$SPARK_HOME/python/lib/py4j-0.10.7-src.zip:/usr/bin/python3
ENV PATH $PATH:$JAVA_HOME/bin:$HADOOP_HOME/bin:$SPARK_HOME/bin:$SPARK_HOME/python:$SPARK_HOME/python/lib/py4j-0.10.7-src.zip:$PYTHONPATH:$HIVE_HOME/bin

# Install dependencies
RUN apt-get update && apt-get install -y curl gnupg2 ca-certificates

# Install Python 3.9
RUN apt-get update && apt-get install -y --no-install-recommends python3 python3-pip python3-dev gcc

# Install Python 3.11
#RUN apt-get install -y python3.11 python3-pip \
#    ln -s /usr/bin/python3.11 /usr/bin/python \
#    ln -s /usr/bin/python3.11 /usr/bin/python3 

COPY /config/jupyter/requirements.txt /

RUN python3 -m pip install -r requirements.txt  --upgrade \
    && python3 -m pip install dask[bag] --upgrade \
    && python3 -m pip install --upgrade toree \
    && python3 -m pip install bash_kernel
    
# Install ssh
RUN apt-get update && apt-get install -y --no-install-recommends ssh openssh-server wget

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
    # Configurando o JAVA_HOME para os processos localizarem a instalação do Java
    && echo "export JAVA_HOME=${JAVA_HOME}" >> /etc/environment

COPY config/hive/*.xml $SPARK_HOME/conf/

COPY config/hadoop/masters $HADOOP_HOME/conf/
COPY config/hadoop/slaves $HADOOP_HOME/conf/

# Todos os arquivos de configuracao que devem ser copiados para dentro do
# container estao aqui
COPY config/spark ${SPARK_HOME}/conf/
COPY config/hadoop/*.xml /usr/hadoop-${HADOOP_VERSION}/etc/hadoop/
COPY config/scripts /

# Porta nodeManager SPark 8042, Porta 9870 NameNode Hadoop  Porta 18080 Spark History Server 
EXPOSE 8042 9870 18080
# Portas Hadoop: 9000 / Spark: 4040, 8080 7077 
EXPOSE 9000 4040 8020 22 8080 7077 8081
# Portas Spark/yarn 8088
EXPOSE 8088 6066 7001 8030 8031 8032 2181 2888 3888  

# Algumas configuracoes adicionais e inicio de alguns servicoes que devem ser feitos em
# tempo de execucao estao presentes no script bootstrap.
# Este cuidará de colocar alguns datasets exemplo dentro do HDFS, bem como de iniciar 
# servicos como HDFS (formatando Namenode), iniciando o Hive, definindo o ID do 
# Zookeeper para que suas diferentes instâncias possam se ver e iniciando este servico.
# O comando ENTRYPOINT define que este script será executado quando os containeres
# iniciarem.
ENTRYPOINT ["/bin/bash", "bootstrap.sh"]
