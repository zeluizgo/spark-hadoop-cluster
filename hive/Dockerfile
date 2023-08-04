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

# Adicao de valores aos paths abaixo para que os componentes os localizem
ENV PYTHONPATH /usr/bin/python3
ENV PATH $PATH:$JAVA_HOME/bin:$PYTHONPATH:$HIVE_HOME/bin:$HADOOP_HOME/bin

# Install dependencies
RUN apt-get update && apt-get install -y curl gnupg2 ca-certificates

# Install Python 3.11
RUN apt-get update && apt-get install -y --no-install-recommends python3 python3-pip python3-dev gcc
#RUN apt-get install -y python3.11 python3-pip \
#    ln -s /usr/bin/python3.11 /usr/bin/python \
#    ln -s /usr/bin/python3.11 /usr/bin/python3 

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

COPY config/hive/*.xml $HIVE_HOME/conf/


# Todos os arquivos de configuracao que devem ser copiados para dentro do
# container estao aqui
COPY config/scripts /

# Portas 10000:10002 relativas ao Hiveserver2, 9999 webui do Hiveserver
EXPOSE 22 9083 10000 10001 10002 9999 3306

# Algumas configuracoes adicionais e inicio de alguns servicoes que devem ser feitos em
# tempo de execucao estao presentes no script bootstrap.
# Este cuidará de colocar alguns datasets exemplo dentro do HDFS, bem como de iniciar 
# servicos como HDFS (formatando Namenode), iniciando o Hive, definindo o ID do 
# Zookeeper para que suas diferentes instâncias possam se ver e iniciando este servico.
# O comando ENTRYPOINT define que este script será executado quando os containeres
# iniciarem.
ENTRYPOINT ["/bin/bash", "bootstrap.sh"]
