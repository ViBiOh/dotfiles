import re
import subprocess
from datetime import datetime, timedelta

import sublime_plugin

import sublime

new_file_regex = re.compile("fatal: no such path '.*' in HEAD")
not_git_regex = re.compile(
    "fatal: not a git repository \\(or any of the parent directories\\): .git"
)
author_regex = re.compile("author\\s(.*)")
time_regex = re.compile("author-time\\s(.*)")
summary_regex = re.compile("summary\\s(.*)")


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


class SublimeGitBlame(sublime_plugin.EventListener):
    _blame_key = "git_blame"

    _filename = ""
    _liner_number = 0

    def clear_blame(self, view):
        view.erase_status(self._blame_key)

    def print_blame(self, view, value):
        view.set_status(self._blame_key, value)

    def on_selection_modified_async(self, view):
        file_name = view.file_name()
        if not file_name or len(file_name) == 0:
            return

        selections = view.sel()
        if len(selections) != 1:
            self.clear_blame(view)
            return

        window = view.window()
        if not window:
            return

        selection = selections[0]
        current_point = selection.begin()
        line_number = view.rowcol(current_point)[0] + 1  # index start at 0

        if line_number != view.rowcol(selection.end())[0] + 1:
            self.clear_blame(view)
            return

        if file_name == self._filename and line_number == self._liner_number:
            return

        self._filename = file_name
        self._liner_number = line_number

        if current_point == view.size():
            self.clear_blame(view)
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
                    file_name,
                ],
                stderr=subprocess.STDOUT,
                cwd=window.extract_variables()["file_path"],
            )
        except subprocess.CalledProcessError as e:
            err_content = e.output.decode("utf8")

            if new_file_regex.match(err_content):
                self.print_blame(view, "New file")
            elif not_git_regex.match(err_content):
                self.print_blame(view, "Not in git")
            else:
                print(err_content, end="")

            return

        blame_content = git_blame.decode("utf8")
        author = author_regex.findall(blame_content)[0]
        if author == "Not Committed Yet":
            self.clear_blame(view)
            return

        time = int(time_regex.findall(blame_content)[0])
        moment = datetime.fromtimestamp(time)
        description = summary_regex.findall(blame_content)[0]
        blame = "{}|{}({}): {}".format(author, relative_time(moment), moment.strftime("%Y-%m-%dT%H:%M:%S%z"), description)

        self.print_blame(view, blame)
