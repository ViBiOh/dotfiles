import os
import re
import subprocess
import threading
from os.path import dirname, isdir

origin_regex = re.compile(
    r"^(?:git@|ssh://git@|https?://)(?P<url>[^/:]+)[/:](?P<repository>.+?)(?:\.git)?/?\s*$"
)
not_git_regex = re.compile(
    r"fatal: not a git repository \(or any of the parent directories\): \.git"
)

_UNSET = object()

_cache_lock = threading.Lock()
_git_path_cache = {}
_git_remote_cache = {}


def git_path(file_name):
    if len(file_name) == 0:
        return

    working_dir = dirname(file_name)

    with _cache_lock:
        cached = _git_path_cache.get(working_dir, _UNSET)
    if cached is not _UNSET:
        return _resolve_git_path(cached, file_name) if cached else None

    if not isdir(working_dir):
        return

    root = None
    try:
        root = (
            subprocess.check_output(
                ["git", "rev-parse", "--is-inside-work-tree", "--show-toplevel"],
                stderr=subprocess.STDOUT,
                cwd=working_dir,
                timeout=5,
            )
            .decode("utf8")
            .strip()
            .splitlines()[-1]
        )
    except (FileNotFoundError, subprocess.TimeoutExpired) as err:
        print(f"unable to get root path: {err}")
        return
    except subprocess.CalledProcessError as err:
        output = err.output.decode("utf8")
        if not not_git_regex.search(output):
            print("unable to get root path: {}".format(output))

    with _cache_lock:
        _git_path_cache[working_dir] = root

    return _resolve_git_path(root, file_name) if root else None


def _resolve_git_path(root, file_name):
    return {
        "root": root,
        "path": os.path.relpath(file_name, root),
    }


def git_remote(cwd):
    with _cache_lock:
        cached = _git_remote_cache.get(cwd)
    if cached is not None:
        return cached

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
        print(f"unable to get remote push url: {err}")
        return ""
    except subprocess.CalledProcessError as err:
        print("unable to get remote push url: {}".format(err.output.decode("utf8")))
        return ""

    origin_match = origin_regex.match(remote)
    url = (
        "https://{}/{}".format(
            origin_match.group("url"),
            origin_match.group("repository"),
        )
        if origin_match
        else ""
    )

    with _cache_lock:
        _git_remote_cache[cwd] = url

    return url
