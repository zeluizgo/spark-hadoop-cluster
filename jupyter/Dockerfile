FROM arm64v8/openjdk:8-jre-slim


# Configuracoes do pyspark
ENV PYSPARK_PYTHON python3

# Usar python3 para modo cluster, e jupyter + configuracao de PYSPARK_DRIVER_PYTHON_OPTS='notebook'
# para modo interativo
ENV PYSPARK_DRIVER_PYTHON=python3
# ENV PYSPARK_DRIVER_PYTHON=jupyter
# ENV PYSPARK_DRIVER_PYTHON_OPTS='notebook'


# Variaveis de ambiente do Hadoop
ENV HADOOP_VERSION 3.3.5
ENV HADOOP_MINOR_VERSION 3
ENV HADOOP_HOME /usr/hadoop-$HADOOP_VERSION
ENV HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop
ENV YARN_CONF_DIR $HADOOP_CONF_DIR

# Adicao de valores aos paths abaixo para que os componentes os localizem
ENV PYTHONPATH /usr/bin/python3
ENV PATH $PATH:$JAVA_HOME/bin:$PYTHONPATH:$HADOOP_HOME/bin

# Install dependencies
RUN apt-get update && apt-get install -y curl gnupg2 ca-certificates

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
    && chown -R root:root ${HADOOP_HOME}

    # Configurando o JAVA_HOME para os processos localizarem a instalação do Java
RUN echo "export JAVA_HOME=${JAVA_HOME}" >> /etc/environment

COPY config/hadoop/*.xml /usr/hadoop-${HADOOP_VERSION}/etc/hadoop/
COPY config/scripts /

# Porta 8888 - jupyter notebook
EXPOSE 22 8888

# Algumas configuracoes adicionais e inicio de alguns servicoes que devem ser feitos em
# tempo de execucao estao presentes no script bootstrap.
# Este cuidará de colocar alguns datasets exemplo dentro do HDFS, bem como de iniciar 
# servicos como HDFS (formatando Namenode), iniciando o Hive, definindo o ID do 
# Zookeeper para que suas diferentes instâncias possam se ver e iniciando este servico.
# O comando ENTRYPOINT define que este script será executado quando os containeres
# iniciarem.
ENTRYPOINT ["/bin/bash", "bootstrap.sh"]
