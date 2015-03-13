#!/usr/bin/python
# -*- coding: utf-8 -*-

import os
import socket
from sensu_plugin import SensuPluginMetricGraphite


class DiskUsage(SensuPluginMetricGraphite):
    node_name = socket.gethostname()
    separator = "."

    def setup(self):
        self.parser.add_argument(
            '-p',
            '--path',
            type=str,
            default="/home/disk",
            help='Directory path'
        )

    def run(self):
        if hasattr(os, 'statvfs'):  # POSIX
            self.disk_usage(self.options.path)
        else:
            raise NotImplementedError("platform not supported")

    def disk_usage(self, path):
        metrics = {}
        st = os.statvfs(path)
        metrics['free'] = st.f_bavail * st.f_frsize
        metrics['total'] = st.f_blocks * st.f_frsize
        metrics['used'] = (st.f_blocks - st.f_bfree) * st.f_frsize
        for key in metrics:
            self.output(self.separator.join([self.node_name, "disk", key]), metrics[key])
        self.ok()


if __name__ == "__main__":
    f = DiskUsage()
    f.run()