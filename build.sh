docker build -t spark-hadoop-cluster ./spark-hadoop
docker build -t hive-server -f ./hive/Dockerfile-hive ./
docker build -t jupyter -f ./jupyter/Dockerfile-jupyter ./