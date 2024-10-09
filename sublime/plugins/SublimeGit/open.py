import re
import subprocess
from os.path import dirname

import sublime_plugin

import sublime

from .utils import git_path

origin_regex = re.compile("^.*@(.*):(.*?)(.git)?\\n?$")


class SublimeGitWeb(sublime_plugin.WindowCommand):
    def run(self):
        window = self.window
        if not window:
            return

        view = window.active_view()

        file_name = view.file_name()
        if not file_name or len(file_name) == 0:
            return

        git_info = git_path(file_name)
        if not git_info:
            return

        line_number = view.rowcol(view.sel()[0].begin())[0] + 1

        try:
            remote = (
                subprocess.check_output(
                    ["git", "remote", "get-url", "--push", "origin"],
                    stderr=subprocess.STDOUT,
                    cwd=git_info["root"],
                )
                .decode("utf8")
                .rstrip()
            )
        except subprocess.CalledProcessError as e:
            print("unable to get remote push url: {}".format(e.output.decode("utf8")))
            return

        try:
            branch = (
                subprocess.check_output(
                    [
                        "git",
                        "log",
                        "-n",
                        "1",
                        "--pretty=format:%h",
                        "--",
                        git_info["path"],
                    ],
                    stderr=subprocess.STDOUT,
                    cwd=git_info["root"],
                )
                .decode("utf8")
                .rstrip()
            )
        except subprocess.CalledProcessError as e:
            print(
                "unable to get last commit of file: {}".format(e.output.decode("utf8"))
            )
            return

        paths = origin_regex.findall(remote)
        url = "https://{}/{}/blob/{}/{}#L{}".format(
            paths[0][0], paths[0][1], branch, git_info["path"], line_number
        )

        sublime.set_clipboard(url)
