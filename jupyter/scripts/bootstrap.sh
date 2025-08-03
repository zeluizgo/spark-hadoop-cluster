#!/bin/bash

# Este trecho rodará independente de termos um container master ou
# worker. Necesário para funcionamento do HDFS e para comunicação
# dos containers/nodes.
/etc/init.d/ssh start

# Caso mantenha notebooks personalizados na pasta que tem bind mount com o 
# container /user_data, o trecho abaixo automaticamente fará o processo de 
# confiar em todos os notebooks, também liberando o server do jupyter de
# solicitar um token
cd /user_data
jupyter trust *.ipynb
jupyter lab --NotebookApp.allow_origin='*' --ip=0.0.0.0 --port=8888 --no-browser --allow-root --NotebookApp.token='' --NotebookApp.password='' 

while :; do sleep 2073600; done
