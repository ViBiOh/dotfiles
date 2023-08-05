import re
import os
import subprocess
import threading

from os.path import exists, join


env_regex = re.compile("^(export )?([a-zA-Z_][a-zA-Z0-9_]*)=(.*)")


def load_env(cwd, name):
    env_file = join(cwd, name)

    if exists(env_file):
        try:
            env_values = subprocess.check_output(
                [
                    "sh",
                    "--norc",
                    "-c",
                    "source '{}' && declare".format(env_file),
                ],
                stderr=subprocess.STDOUT,
                cwd=cwd,
            )
        except subprocess.CalledProcessError as e:
            print("unable to source .env: {}".format(e.output.decode("utf8")))
            return None

        env = {}
        for line in env_values.decode("utf8").rstrip().split("\n"):
            if env_regex.match(line):
                parts = env_regex.findall(line)
                env[parts[0][1]] = parts[0][2]

        return env

    return None


def load_git_root_env(cwd):
    is_git = subprocess.call(["git", "rev-parse", "--is-inside-work-tree"], cwd=cwd)
    if is_git != 0:
        print("not in git")
        return None

    try:
        git_root = subprocess.check_output(
            ["git", "rev-parse", "--show-toplevel"],
            stderr=subprocess.STDOUT,
            cwd=cwd,
        )
    except subprocess.CalledProcessError as e:
        print("unable to get root path: {}".format(e.output.decode("utf8")))
        return None

    root = git_root.decode("utf8").rstrip()

    return load_env(root, ".env")
