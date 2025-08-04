import re
import subprocess
from datetime import datetime, timedelta
from os.path import dirname

import sublime_plugin

import sublime

from .open import build_line_url
from .utils import git_path, git_remote

PLUGIN_NAME = "SublimeGit"
PLUGIN_SETTINGS = "{}.sublime-settings".format(PLUGIN_NAME)

new_file_regex = re.compile("fatal: no such path '.*' in HEAD")
not_git_regex = re.compile(
    "fatal: not a git repository \\(or any of the parent directories\\): .git"
)
line_regex = re.compile(
    "^(?P<sha>[a-f0-9]{40})\\s(?P<origin_line>[0-9]+)\\s(?P<final_line>[0-9]+)"
)
author_regex = re.compile("^author\\s(?P<author>.*)")
time_regex = re.compile("^author-time\\s(?P<time>.*)")
summary_regex = re.compile("^summary\\s(?P<summary>.*)")


def plugin_loaded() -> None:
    global _settings_obj
    loaded_settings_obj = sublime.load_settings(PLUGIN_SETTINGS)
    _settings_obj = loaded_settings_obj


# From https://gist.github.com/jonlabelle/7d306575cbbd34b154f87b1853d532cc
def relative_time(date):
    def formatn(n, s):
        if n == 1:
            return "1 %s" % s
        elif n > 1:
            return "%d %ss" % (n, s)

    def qnr(a, b):
        return int(a / b), a % b

    class FormatDelta:
        def __init__(self, dt):
            now = datetime.now()
            delta = now - dt
            self.day = delta.days
            self.second = delta.seconds
            self.year, self.day = qnr(self.day, 365)
            self.month, self.day = qnr(self.day, 30)
            self.hour, self.second = qnr(self.second, 3600)
            self.minute, self.second = qnr(self.second, 60)

        def format(self):
            for period in ["year", "month", "day", "hour", "minute", "second"]:
                n = getattr(self, period)
                if n >= 1:
                    return "{0} ago".format(formatn(n, period))
            return "just now"

    return FormatDelta(date).format()


def parse_blame(blame):
    lines = {}
    commits = {}

    current_sha = ""
    current_commit = None

    for line in blame.splitlines():
        line_match = line_regex.match(line)
        if line_match:
            if current_commit:
                commits[current_commit.get("sha")] = current_commit

            current_sha = line_match.group("sha")
            lines[int(line_match.group("final_line"))] = current_sha

            if not commits.get(current_sha, None):
                current_commit = {"sha": current_sha}

            continue

        author_match = author_regex.match(line)
        if author_match:
            current_commit["author"] = author_match.group("author")
            continue

        time_match = time_regex.match(line)
        if time_match:
            current_commit["time"] = datetime.fromtimestamp(
                int(time_match.group("time"))
            )
            continue

        summary_match = summary_regex.match(line)
        if summary_match:
            current_commit["summary"] = summary_match.group("summary")
            continue

    if current_commit:
        commits[current_commit.get("sha")] = current_commit

    return {
        "lines": lines,
        "commits": commits,
    }


class SublimeGitDisableBlame(sublime_plugin.WindowCommand):
    def run(self):
        _settings_obj.set("show_blame", False)
        self.window.active_view().erase_regions("git_blame")


class SublimeGitEnableBlame(sublime_plugin.WindowCommand):
    def run(self):
        _settings_obj.set("show_blame", True)


class SublimeGitBlame(sublime_plugin.EventListener):
    _status_key = "git_blame"

    _git_info = {}
    _git_blame = None
    _git_remote = ""

    _file_name = ""
    _line_number = 0

    def clear_status(self, view):
        view.erase_regions(self._status_key)

    def print_status(self, view, selection, author, moment, description, url):
        content = '<a href="{}">{}</a> <span style="color: var(--{})">({})</span> <span style="color: var(--{})">&lt;{}&gt;</span>'.format(
            url,
            description,
            "greenish",
            relative_time(moment),
            "purplish",
            author,
        )

        view.add_regions(
            self._status_key,
            [selection],
            self._status_key,
            flags=sublime.HIDDEN | sublime.PERSISTENT,
            annotations=[content],
            annotation_color="coral",
        )

    def refresh_file(self, view):
        file_name = view.file_name()
        if not file_name or len(file_name) == 0:
            return

        if self._file_name != file_name or self._git_blame is None:
            git_info = git_path(file_name)

            if not git_info:
                return

            try:
                git_blame = subprocess.check_output(
                    [
                        "git",
                        "blame",
                        "--porcelain",
                        "--",
                        git_info["path"],
                    ],
                    stderr=subprocess.STDOUT,
                    cwd=git_info["root"],
                )
            except subprocess.CalledProcessError as e:
                err_content = e.output.decode("utf8")

                if new_file_regex.match(err_content):
                    self.print_status(view, "New file")
                elif not_git_regex.match(err_content):
                    self.print_status(view, "Not in git")
                else:
                    print(err_content, end="")

                return

            self._file_name = file_name
            self._git_info = git_info
            self._git_blame = parse_blame(git_blame.decode("utf8"))
            self._git_remote = git_remote(git_info["root"])

    def on_post_save_async(self, view):
        if not _settings_obj.get("show_blame", False):
            return

        self.refresh_file(view)

    def on_selection_modified_async(self, view):
        if not _settings_obj.get("show_blame", False):
            return

        self.refresh_file(view)

        if self._git_blame is None:
            return

        selections = view.sel()
        if len(selections) != 1:
            self.clear_status(view)
            return

        selection = selections[0]
        current_point = selection.begin()
        line_number = view.rowcol(current_point)[0] + 1  # index start at 0

        if line_number == self._line_number:
            return

        if line_number != view.rowcol(selection.end())[0] + 1:
            self.clear_status(view)
            return

        self._line_number = line_number

        if current_point == view.size():
            self.clear_status(view)
            return

        sha = self._git_blame.get("lines").get(self._line_number)
        if sha == "0000000000000000000000000000000000000000":
            self.clear_status(view)
            return

        commit = self._git_blame.get("commits").get(sha)
        if not commit:
            return

        author = commit.get("author")
        moment = commit.get("time")
        description = commit.get("summary")

        self.print_status(
            view,
            selection,
            author,
            moment,
            description,
            build_line_url(
                self._git_remote, sha, self._git_info["path"], self._line_number
            ),
        )


class SublimeGitDisableCodeowners(sublime_plugin.WindowCommand):
    def run(self):
        _settings_obj.set("show_codeowners", False)
        self.window.active_view().erase_status("git_codeowners")


class SublimeGitEnableCodeowners(sublime_plugin.WindowCommand):
    def run(self):
        _settings_obj.set("show_codeowners", True)


class SublimeGitCodeowners(sublime_plugin.EventListener):
    _status_key = "git_codeowners"

    _file_name = ""
    _git_info = {}

    def clear_status(self, view):
        view.erase_status(self._status_key)

    def print_status(self, view, value):
        view.set_status(self._status_key, value)

    def on_selection_modified_async(self, view):
        if not _settings_obj.get("show_codeowners", True):
            return

        file_name = view.file_name()
        if not file_name or len(file_name) == 0:
            return

        if file_name == self._file_name:
            return

        _git_info = git_path(file_name)
        if not _git_info:
            return

        self._file_name = file_name
        self._git_info = _git_info

        try:
            owners = subprocess.check_output(
                [
                    "codeowners",
                    "--",
                    self._git_info["path"],
                ],
                stderr=subprocess.STDOUT,
                cwd=self._git_info["root"],
            )

            self.print_status(
                view, owners.decode("utf8").replace(self._git_info["path"], "").strip()
            )
        except subprocess.CalledProcessError as e:
            print(e.output.decode("utf8"), end="")
