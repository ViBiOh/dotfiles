import re
import sublime
import sublime_plugin
import subprocess


origin_regex = re.compile("^.*@(.*):(.*).git\\n?$")


class SublimeGitWeb(sublime_plugin.WindowCommand):
    def run(self):
        window = self.window
        if not window:
            return

        view = window.active_view()

        file_name = view.file_name()
        if not file_name or len(file_name) == 0:
            return

        variables = window.extract_variables()
        working_dir = variables["file_path"]

        line_number = view.rowcol(view.sel()[0].begin())[0] + 1  # index start at 0

        is_git = subprocess.call(
            ["git", "rev-parse", "--is-inside-work-tree"], cwd=working_dir
        )
        if is_git != 0:
            return

        try:
            git_remote_url = subprocess.check_output(
                ["git", "remote", "get-url", "--push", "origin"],
                stderr=subprocess.STDOUT,
                cwd=working_dir,
            )
        except subprocess.CalledProcessError as e:
            print("unable to get remote push url: {}".format(e.output.decode("utf8")))
            return

        try:
            git_root = subprocess.check_output(
                ["git", "rev-parse", "--show-toplevel"],
                stderr=subprocess.STDOUT,
                cwd=working_dir,
            )
        except subprocess.CalledProcessError as e:
            print("unable to get root path: {}".format(e.output.decode("utf8")))
            return

        try:
            git_branch = subprocess.check_output(
                ["git", "rev-parse", "--abbrev-ref", "HEAD"],
                stderr=subprocess.STDOUT,
                cwd=working_dir,
            )
        except subprocess.CalledProcessError as e:
            print("unable to get branch: {}".format(e.output.decode("utf8")))
            return

        remote = git_remote_url.decode("utf8").rstrip()
        root = git_root.decode("utf8").rstrip()
        git_path = working_dir.replace(root, "")
        branch = git_branch.decode("utf8").rstrip()

        paths = origin_regex.findall(remote)
        url = "https://{}/{}/blob/{}{}/{}#L{}".format(
            paths[0][0], paths[0][1], branch, git_path, file_name, line_number
        )

        sublime.set_clipboard(url)
