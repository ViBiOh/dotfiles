import re
import subprocess

import sublime_plugin

import sublime

origin_regex = re.compile("^.*@(.*):(.*?)(.git)?\\n?$")


class SublimeGitWeb(sublime_plugin.WindowCommand):
    def run(self):
        window = self.window
        if not window:
            return

        variables = window.extract_variables()
        working_dir = variables.get("file_path")
        file_name = variables.get("file_name")

        if not file_name or len(file_name) == 0:
            return

        view = window.active_view()
        line_number = view.rowcol(view.sel()[0].begin())[0] + 1

        is_git = subprocess.call(
            ["git", "rev-parse", "--is-inside-work-tree"], cwd=working_dir
        )
        if is_git != 0:
            return

        try:
            remote = (
                subprocess.check_output(
                    ["git", "remote", "get-url", "--push", "origin"],
                    stderr=subprocess.STDOUT,
                    cwd=working_dir,
                )
                .decode("utf8")
                .rstrip()
            )
        except subprocess.CalledProcessError as e:
            print("unable to get remote push url: {}".format(e.output.decode("utf8")))
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

        git_path = working_dir.replace(root, "")

        try:
            branch = (
                subprocess.check_output(
                    ["git", "log", "-n", "1", "--pretty=format:%h", "--", file_name],
                    stderr=subprocess.STDOUT,
                    cwd=working_dir,
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
        url = "https://{}/{}/blob/{}{}/{}#L{}".format(
            paths[0][0], paths[0][1], branch, git_path, file_name, line_number
        )

        sublime.set_clipboard(url)
