import re
import sublime_plugin
import subprocess

from datetime import datetime, timedelta

new_file_regex = re.compile("fatal: no such path '.*' in HEAD")
not_git_regex = re.compile("fatal: not a git repository \\(or any of the parent directories\\): .git")
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
        return a / b, a % b

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
            for period in ['year', 'month', 'day', 'hour', 'minute', 'second']:
                n = getattr(self, period)
                if n >= 1:
                    return '{0} ago'.format(formatn(n, period))
            return "just now"

    return FormatDelta(date).format()

class GitBlameSelection(sublime_plugin.EventListener):
    _last_filename = ""
    _last_linenumber = 0

    def on_selection_modified_async(self, view):
        vars = view.window().extract_variables()
        file_name = vars['file_name']
        line_number = view.rowcol(view.sel()[0].begin())[0]

        if file_name == self._last_filename and line_number == self._last_linenumber:
            return

        self._last_filename = file_name
        self._last_linenumber = line_number

        working_dir = vars['file_path']

        gitblame = subprocess.Popen(['git', 'blame', '-p', '-L', '{},{}'.format(line_number, line_number), '--', file_name], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=working_dir)
        gitblame_out, gitblame_err = gitblame.communicate("")
        if gitblame.returncode != 0:
            err_content = gitblame_err.decode()

            if new_file_regex.match(err_content):
                view.set_status("git_blame", "Blame: new file")
            elif not_git_regex.match(err_content):
                view.set_status("git_blame", "Blame: not in git")
            else:
                print(err_content, end="")
            return

        blame_content = gitblame_out.decode()

        author = author_regex.findall(blame_content)[0]
        moment = datetime.fromtimestamp(int(time_regex.findall(blame_content)[0]))
        description = summary_regex.findall(blame_content)[0]

        view.set_status("git_blame", '{} by {}: {}'.format(relative_time(moment), author, description))
