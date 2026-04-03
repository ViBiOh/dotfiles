import re
import subprocess
from os.path import dirname, isdir

origin_regex = re.compile("^.*@(?P<url>.*):(?P<repository>.*?)(.git)?\\n?$")


def git_path(file_name):
    if len(file_name) == 0:
        return

    working_dir = dirname(file_name)

    if not isdir(working_dir):
        return

    is_git = subprocess.call(
        ["git", "rev-parse", "--is-inside-work-tree"], cwd=working_dir
    )
    if is_git != 0:
        return

    try:
        root = (
            subprocess.check_output(
                ["git", "rev-parse", "--show-toplevel"],
                stderr=subprocess.STDOUT,
                cwd=working_dir,
            )
            .decode("utf8")
            .rstrip()
        )
    except subprocess.CalledProcessError as e:
        print("unable to get root path: {}".format(e.output.decode("utf8")))
        return

    return {
        "root": root,
        "path": file_name.replace(root, "").lstrip("/"),
    }


def git_remote(cwd):
    try:
        remote = (
            subprocess.check_output(
                ["git", "remote", "get-url", "--push", "origin"],
                stderr=subprocess.STDOUT,
                cwd=cwd,
            )
            .decode("utf8")
            .rstrip()
        )

        origin_match = origin_regex.match(remote)
        if origin_match:
            return "https://{}/{}".format(
                origin_match.group("url"),
                origin_match.group("repository"),
            )

    except subprocess.CalledProcessError as e:
        print("unable to get remote push url: {}".format(e.output.decode("utf8")))

    return ""
