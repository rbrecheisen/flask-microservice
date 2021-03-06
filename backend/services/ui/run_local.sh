#!/usr/bin/env bash

# ----------------------------------------------------------------------------------------
# Cleanup database
rm -f /tmp/yoda.db

# ----------------------------------------------------------------------------------------
state=$(docker-machine ls | grep default | awk '{print $4}')
if [ "${state}" != "Running" ]; then
    docker-machine start default
fi
eval $(docker-machine env default)

# ----------------------------------------------------------------------------------------
# Build base Nginx image
docker build -t brecheisen/nginx-base:v1 ../base/nginx

# ----------------------------------------------------------------------------------------
# Check if storage containers are still running. If so, kill them
container=$(docker ps | grep brecheisen/storage:v1 | awk '{print $1}')
if [ "${container}" != "" ]; then
    docker stop ${container}; docker rm ${container}
fi
# Build storage image
docker build -t brecheisen/storage:v1 ../storage
# Create temporary container for file storage. This will be used by the Nginx
# storage proxy as well as the storage app
container=$(docker ps -a | grep busybox:1.25 | awk '{print $1}')
if [ "${container}" != "" ]; then
    docker rm ${container}
fi
# Run file storage container
rm -rf ./files
mkdir -p ./files
docker create --name files -v $(pwd)/files:/mnt/shared/files busybox:1.25 /bin/true
# Run storage service. Because it's running inside a container and needs to
# contact the storage app running on the host system, we provide the IP
# address of the VM
docker run -d \
    -e "STORAGE_APP_SERVICE_HOST=192.168.99.1" \
    -e "STORAGE_APP_SERVICE_PORT=5003" \
    --volumes-from files \
    -p 5002:5002 \
    brecheisen/storage:v1 ./run.sh

# ----------------------------------------------------------------------------------------
# Check if UI containers are still running. If so, kill them
container=$(docker ps | grep brecheisen/ui:v1 | awk '{print $1}')
if [ "${container}" != "" ]; then
    docker stop ${container}; docker rm ${container}
fi
# Build UI image
docker build -t brecheisen/ui:v1 .
# Run UI service. Because the storage service is also running inside a
# container it's IP address is different from the other services which
# are running directly on the host. We mount the ./static folder so we
# can easily refresh the browser window to load the new HTML and JavaScript.
docker run -d \
    -e "AUTH_SERVICE_HOST=192.168.99.1" \
    -e "AUTH_SERVICE_PORT=5000" \
    -e "COMPUTE_SERVICE_HOST=192.168.99.1" \
    -e "COMPUTE_SERVICE_PORT=5001" \
    -e "STORAGE_SERVICE_HOST=192.168.99.100" \
    -e "STORAGE_SERVICE_PORT=5002" \
    -e "UI_SERVICE_HOST=192.168.99.100" \
    -e "UI_SERVICE_PORT=80" \
    -v $(pwd)/static:/usr/local/nginx/html \
    -p 80:80 \
    brecheisen/ui:v1 ./run.sh

# ----------------------------------------------------------------------------------------
# Check if RabbitMQ container running. If so, kill it
container=$(docker ps | grep rabbitmq:3.6 | awk '{print $1}')
if [ "${container}" != "" ]; then
    docker stop ${container}; docker rm ${container}
fi
# Run RabbitMQ from default Docker registry
docker run -d \
    --name rabbitmq \
    --hostname my-rabbitmq \
    -p 5672:5672 \
    rabbitmq:3.6

# ----------------------------------------------------------------------------------------
# Check if Redis container still running. If so, kill it
container=$(docker ps | grep redis:3.0-alpine | awk '{print $1}')
if [ "${container}" != "" ]; then
    docker stop ${container}; docker rm ${container}
fi
# Run Redis from default Docker registry
docker run -d \
    --name redis \
    -p 6379:6379 \
    redis:3.0-alpine

# ----------------------------------------------------------------------------------------
# Clean up any dangling images
dangling=$(docker images -qf "dangling=true")
if [ "${dangling}" != "" ]; then
    docker rmi -f $(docker images -qf "dangling=true")
fi

# ----------------------------------------------------------------------------------------
# Show containers
docker ps -a