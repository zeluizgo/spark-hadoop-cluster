
# Requires a buildx builder with arm64 support.
# One-time setup: docker buildx create --name arm64builder --use && docker buildx inspect --bootstrap

docker buildx build --platform linux/arm64 --load -t spark-hadoop-cluster ./spark-hadoop
docker tag spark-hadoop-cluster ubuntu-pi-03:5000/spark-hadoop-cluster
docker push ubuntu-pi-03:5000/spark-hadoop-cluster

docker buildx build --platform linux/arm64 --load -t jupyter -f ./jupyter/Dockerfile-jupyter ./
docker tag jupyter ubuntu-pi-03:5000/jupyter
docker push ubuntu-pi-03:5000/jupyter

docker buildx build --platform linux/arm64 --load -t hive -f ./hive/Dockerfile-hive ./
docker tag hive ubuntu-pi-03:5000/hive
docker push ubuntu-pi-03:5000/hive
#docker stack deploy --compose-file=docker-compose.yml spark-hadoop