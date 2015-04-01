#!/usr/bin/python

from docker import Client
import string
import syslog
import os
import subprocess


class PreInitConfig(object):
    def __init__(self):
        self.docker_url = "unix://var/run/docker.sock"
        self.docker_version = "1.16"
        self.init_script = "/etc/sensu/sensu-init.sh"
        self.swarm_container = os.environ.get("SWARM_AGENT_NAME", "swarm-agent")
        self.run()

    def run(self):
        self.check_node()
        self.run_service()

    def check_node(self):
        try:
            docker_client = Client(base_url=self.docker_url, version=self.docker_version)
            node_ip_port = docker_client.inspect_container(self.swarm_container).get("Args", [])

            if node_ip_port:
                node_ip, node_port = string.split(node_ip_port[2], ":")
                os.environ["NODE_NAME"] = str(node_ip)
                os.environ["NODE_IP"] = str(node_ip)
                os.environ["NODE_PORT"] = str(node_port)
        except Exception as e:
            syslog.syslog(syslog.LOG_ERR, "Sensu Client Pre-init:check_node Error: " + e.__str__())

    def run_service(self):
        try:
            subprocess.call([self.init_script])
        except Exception as e:
            syslog.syslog(syslog.LOG_ERR, "Sensu Client Pre-init:run_service Error: " + e.__str__())


if __name__ == "__main__":
    f = PreInitConfig()