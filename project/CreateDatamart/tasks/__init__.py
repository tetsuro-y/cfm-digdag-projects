#!/usr/bin/env python
# -*- coding: utf-8 -*-

import digdag
import subprocess


class PrepareEnviroments(object):
    def set_parameters(self):
        params = digdag.env.params["my_param"]
        for param in params:
            value = self.get_parameter(param)
            digdag.env.store({param: value})

    def get_parameter(self, parameter_name):
        command = "env | grep %s" % parameter_name
        proc = subprocess.Popen(
            command,
            shell=True,
            stdin=subprocess.PIPE,   # 1
            stdout=subprocess.PIPE,  # 2
            stderr=subprocess.PIPE)  # 3

        stdout_data, stderr_data = proc.communicate()  # 処理実行を待つ

        value = stdout_data.decode("utf-8").split("=")[1].replace('\n', '')
        return value
