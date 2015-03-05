#!/usr/bin/env bash

if [ ! -f /etc/sensu/conf.d/config.json ]; then
	ADDRESS=$(awk "/$HOSTNAME/ "'{ print $1 }' /etc/hosts)

# Sets client config                                                                                        
cat > /etc/sensu/conf.d/config.json <<EOF                                                                  
{                                                                                                             
  "client": {                                                                                                 
    "name": "$HOSTNAME",                                                        
    "address": "$ADDRESS",                                                                                   
    "subscriptions": [                                                                                        
        "cpu-metrics",                                                                                        
        "memory-metrics",                                                                                     
        "docker-cpu-metrics",                                                                                 
        "docker-memory-metrics"                                                                               
     ]                                                                                                        
  },                                                                                                          
  "rabbitmq": {                                                                                               
    "ssl": false,
    "host": "rMQ",
    "port": $RMQ_PORT_5672_TCP_PORT,
    "vhost": "/",
    "user": "rabbit",
    "password": "rabbit"
  }
}
EOF
fi

# Start Supervisord
/usr/bin/supervisord -c /etc/supervisord.conf