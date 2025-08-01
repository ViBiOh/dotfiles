import re
import subprocess
from datetime import datetime, timedelta
from os.path import dirname

import sublime_plugin

import sublime

from .utils import git_path

PLUGIN_NAME = "SublimeGit"
PLUGIN_SETTINGS = "{}.sublime-settings".format(PLUGIN_NAME)

new_file_regex = re.compile("fatal: no such path '.*' in HEAD")
not_git_regex = re.compile(
    "fatal: not a git repository \\(or any of the parent directories\\): .git"
)
author_regex = re.compile("author\\s(.*)")
time_regex = re.compile("author-time\\s(.*)")
summary_regex = re.compile("summary\\s(.*)")


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


class SublimeGitDisableBlame(sublime_plugin.WindowCommand):
    def run(self):
        _settings_obj.set("show_blame", "")
        self.window.active_view().erase_status("git_blame")


class SublimeGitEnableBlame(sublime_plugin.WindowCommand):
    def run(self):
        _settings_obj.set("show_blame", "true")


class SublimeGitBlame(sublime_plugin.EventListener):
    _status_key = "git_blame"

    _file_name = ""
    _git_info = {}
    _line_number = 0

    def clear_status(self, view):
        view.erase_regions(self._status_key)

    def print_status(self, view, selection, author, moment, description):
        content = '{} <span style="color: var(--{})">({})</span> <span style="color: var(--{})">({})</span> <span style="color: var(--{})">&lt;{}&gt;</span>'.format(
            description,
            "greenish",
            relative_time(moment),
            "purplish",
            moment.strftime("%Y-%m-%dT%H:%M:%S%z"),
            "bluish",
            author,
        )

        view.add_regions(
            self._status_key,
            [selection],
            annotations=[content],
            annotation_color="coral",
        )

    def on_selection_modified_async(self, view):
        if not _settings_obj.get("show_blame", ""):
            return

        file_name = view.file_name()
        if not file_name or len(file_name) == 0:
            return

        selections = view.sel()
        if len(selections) != 1:
            self.clear_status(view)
            return

        selection = selections[0]
        current_point = selection.begin()
        line_number = view.rowcol(current_point)[0] + 1  # index start at 0

        if line_number != view.rowcol(selection.end())[0] + 1:
            self.clear_status(view)
            return

        if line_number == self._line_number and self._file_name == file_name:
            return

        self._line_number = line_number

        if self._file_name != file_name:
            git_info = git_path(file_name)

            if not git_info and line_number == self._line_number:
                return

            self._file_name = file_name
            self._git_info = git_info

        if current_point == view.size():
            self.clear_status(view)
            return

        try:
            git_blame = subprocess.check_output(
                [
                    "git",
                    "blame",
                    "-w",
                    "--porcelain",
                    "-L",
                    "{},{}".format(line_number, line_number),
                    "--",
                    self._git_info["path"],
                ],
                stderr=subprocess.STDOUT,
                cwd=self._git_info["root"],
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

        blame_content = git_blame.decode("utf8")
        author = author_regex.findall(blame_content)[0]
        if author == "Not Committed Yet":
            self.clear_status(view)
            return

        time = int(time_regex.findall(blame_content)[0])
        moment = datetime.fromtimestamp(time)
        description = summary_regex.findall(blame_content)[0]

        self.print_status(view, selection, author, moment, description)


class SublimeGitDisableCodeowners(sublime_plugin.WindowCommand):
    def run(self):
        _settings_obj.set("show_codeowners", "")
        self.window.active_view().erase_status("git_codeowners")


class SublimeGitEnableCodeowners(sublime_plugin.WindowCommand):
    def run(self):
        _settings_obj.set("show_codeowners", "true")


class SublimeGitCodeowners(sublime_plugin.EventListener):
    _status_key = "git_codeowners"

    _file_name = ""
    _git_info = {}

    def clear_status(self, view):
        view.erase_status(self._status_key)

    def print_status(self, view, value):
        view.set_status(self._status_key, value)

    def on_selection_modified_async(self, view):
        if not _settings_obj.get("show_codeowners", ""):
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
