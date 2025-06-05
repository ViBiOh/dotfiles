import re
import subprocess
from os.path import dirname

import sublime_plugin

import sublime

from .utils import git_path

origin_regex = re.compile("^.*@(.*):(.*?)(.git)?\\n?$")


# Use removeprefix when migrating to 3.9+
def remove_prefix(text, prefix):
    if text.startswith(prefix):
        return text[len(prefix) :]
    return text


class SublimeGitType(sublime_plugin.ListInputHandler):
    def name(self):
        return "git_type"

    def list_items(self):
        return ["Last SHA", "File last SHA", "Branch", "Default branch"]


class SublimeGitWeb(sublime_plugin.WindowCommand):
    def input(self, args):
        return SublimeGitType()

    def run(self, git_type):
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

        if git_type in ["Last SHA", "File last SHA"]:
            args = [
                "git",
                "log",
                "-n",
                "1",
                "--pretty=format:%h",
            ]

            if git_type == "File last SHA":
                args += ["--", git_info["path"]]

            try:
                ref = (
                    subprocess.check_output(
                        args,
                        stderr=subprocess.STDOUT,
                        cwd=git_info["root"],
                    )
                    .decode("utf8")
                    .rstrip()
                )
            except subprocess.CalledProcessError as e:
                print("unable to get SHA: {}".format(e.output.decode("utf8")))
                return

        if git_type in ["Branch", "Default branch"]:
            args = [
                "git",
                "rev-parse",
                "--abbrev-ref",
            ]

            if git_type == "Branch":
                args += ["HEAD"]
            elif "Default branch":
                args += ["origin/HEAD"]

            try:
                ref = (
                    subprocess.check_output(
                        args,
                        stderr=subprocess.STDOUT,
                        cwd=git_info["root"],
                    )
                    .decode("utf8")
                    .rstrip()
                )

                if git_type == "Default branch":
                    ref = remove_prefix(ref, "origin/")
            except subprocess.CalledProcessError as e:
                print("unable to get branch: {}".format(e.output.decode("utf8")))
                return

        paths = origin_regex.findall(remote)
        url = "https://{}/{}/blob/{}/{}#L{}".format(
            paths[0][0], paths[0][1], ref, git_info["path"], line_number
        )

        sublime.set_clipboard(url)
