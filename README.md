Sensu Client
==============
The Sensu client runs on all of your systems that you want to monitor.

Depends on: RabbitMQ

Installation
--------------

1. Install [Docker](https://www.docker.com)

2. Download automated build from public Docker Hub Registry: `docker pull qapps/sensu-client`
(alternatively, you can build an image from Dockerfile: `docker build -t="qapps/sensu-client" github.com/qualiapps/sensu-client`)

Running
-----------------

`docker run -d -P -v /sys/fs/cgroup:/home/cgroup -v /:/home/disk -h $(hostname) -e "NODE_NAME=$(hostname)" -e "NODE_IP=$(hostname -i)" --link rabbitmq:rmq --name sensuClient qapps/sensu-client`

`rabbitmq` - your rabbit container name