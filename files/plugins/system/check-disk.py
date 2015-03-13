#!/usr/bin/python
# -*- coding: utf-8 -*-

import os
from sensu_plugin import SensuPluginCheck


class CheckDiskUsage(SensuPluginCheck):
    def setup(self):
        self.parser.add_argument(
            '-w',
            '--warning',
            type=int,
            default=85,
            help='Warn if PERCENT or more of disk full'
        )
        self.parser.add_argument(
            '-c',
            '--critical',
            type=int,
            default=95,
            help='Critical if PERCENT or more of disk full'
        )
        self.parser.add_argument(
            '-p',
            '--path',
            type=str,
            default="/home/disk",
            help='Directory path'
        )
        self.parser.add_argument(
            '-m',
            '--message',
            type=str,
            default="{0}% free disk left",
            help='Success message'
        )

    def run(self):
        used_percent = self.disk_usage(self.options.path)
        message = self.options.message.format(used_percent)
        if used_percent < self.options.warning and used_percent < self.options.critical:
            self.ok(message)
        elif used_percent >= self.options.critical:
            self.critical(message)
        elif used_percent >= self.options.warning:
            self.warning(message)
        else:
            self.unknown(message)

    @staticmethod
    def disk_usage(path):
        metrics = {}
        st = os.statvfs(path)
        metrics['free'] = st.f_bavail * st.f_frsize
        metrics['total'] = st.f_blocks * st.f_frsize
        metrics['used'] = (st.f_blocks - st.f_bfree) * st.f_frsize

        return metrics['used'] * 100 / metrics['total']


if __name__ == "__main__":
    f = CheckDiskUsage()
    f.run()