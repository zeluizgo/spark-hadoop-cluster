
docker build --platform linux/arm64 -t spark-hadoop-cluster ./spark-hadoop
docker tag spark-hadoop-cluster ubuntu-pi-03:5000/spark-hadoop-cluster
docker push ubuntu-pi-03:5000/spark-hadoop-cluster


docker build --platform linux/arm64 -t jupyter -f ./jupyter/Dockerfile-jupyter ./
docker tag jupyter ubuntu-pi-03:5000/jupyter
docker push ubuntu-pi-03:5000/jupyter
#docker stack deploy --compose-file=docker-compose.yml spark-hadoop     