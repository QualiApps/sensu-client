#!/usr/bin/env bash

if [ ! -f /etc/sensu/conf.d/config.json ]; then

# Sets client config                                                                                        
cat > /etc/sensu/conf.d/config.json <<EOF                                                                  
{                                                                                                             
  "client": {                                                                                                 
    "name": "$NODE_NAME",                                                        
    "address": "$NODE_IP",                                                                                   
    "subscriptions": [                                                                                        
        "cpu-metrics",                                                                                        
        "memory-metrics",                                                                                     
        "docker-cpu-metrics",                                                                                 
        "docker-memory-metrics",
        "cpu-check",
        "ram-check",
        "disk-check",
        "docker-status-metrics",
        "docker-processes-metrics",
        "disk-metrics"
     ]                                                                                                        
  },                                                                                                          
  "rabbitmq": {                                                                                               
    "ssl": false,
    "host": "${FEED_NAME:-feed}",
    "port": ${FEED_PORT:-5672},
    "vhost": "${RMQ_VHOST:-/}",
    "user": "${RMQ_USER:-rabbit}",
    "password": "${RMQ_PASS:-rabbit}"
  }
}
EOF
fi

# Set the docker.sock user as sensu
chown sensu /var/run/docker.sock

# Start Supervisord
/usr/bin/supervisord -c /etc/supervisord.conf