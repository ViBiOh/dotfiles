import subprocess
from os.path import dirname


def git_path(file_name):
    if len(file_name) == 0:
        return

    working_dir = dirname(file_name)

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
