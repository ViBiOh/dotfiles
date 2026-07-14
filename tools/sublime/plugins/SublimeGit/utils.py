import os
import re
import subprocess
from os.path import dirname, isdir

origin_regex = re.compile(
    r"^(?:git@|ssh://git@|https?://)(?P<url>[^/:]+)[/:](?P<repository>.+?)(?:\.git)?/?\s*$"
)


def git_path(file_name):
    if len(file_name) == 0:
        return

    working_dir = dirname(file_name)

    if not isdir(working_dir):
        return

    try:
        is_git = subprocess.call(
            ["git", "rev-parse", "--is-inside-work-tree"],
            cwd=working_dir,
            timeout=5,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired) as err:
        print("unable to check git: {}".format(err))
        return

    if is_git != 0:
        return

    try:
        root = (
            subprocess.check_output(
                ["git", "rev-parse", "--show-toplevel"],
                stderr=subprocess.STDOUT,
                cwd=working_dir,
                timeout=5,
            )
            .decode("utf8")
            .rstrip()
        )
    except (FileNotFoundError, subprocess.TimeoutExpired) as err:
        print("unable to get root path: {}".format(err))
        return
    except subprocess.CalledProcessError as err:
        print("unable to get root path: {}".format(err.output.decode("utf8")))
        return

    return {
        "root": root,
        "path": os.path.relpath(file_name, root),
    }


def git_remote(cwd):
    try:
        remote = (
            subprocess.check_output(
                ["git", "remote", "get-url", "--push", "origin"],
                stderr=subprocess.STDOUT,
                cwd=cwd,
                timeout=5,
            )
            .decode("utf8")
            .rstrip()
        )
    except (FileNotFoundError, subprocess.TimeoutExpired) as err:
        print("unable to get remote push url: {}".format(err))
        return ""
    except subprocess.CalledProcessError as err:
        print("unable to get remote push url: {}".format(err.output.decode("utf8")))
        return ""

    origin_match = origin_regex.match(remote)
    if origin_match:
        return "https://{}/{}".format(
            origin_match.group("url"),
            origin_match.group("repository"),
        )

    return ""
