#!/usr/bin/python
# -*- coding: utf-8 -*-
import sys
import os

from sensu_plugin import SensuPluginMetricGraphite
from docker import Client


class GetRunningContainers(SensuPluginMetricGraphite):
    def setup(self):
        self.parser.add_argument(
            '-d',
            '--docker',
            type=str,
            default=os.environ.get("NODE_IP", "127.0.0.1"),
            help='Docker hostname'
        )

    def run(self):
        docker_client = Client(base_url='tcp://' + self.options.docker + ':2375', version='1.16')
        for container in docker_client.containers(all=True):
            self.output(container['Id'] + '.run', self.check_status(container['Status']))
        self.ok()

    @staticmethod
    def check_status(status):
        return 1 if status.find("Up") != -1 else 0


if __name__ == "__main__":
    f = GetRunningContainers()