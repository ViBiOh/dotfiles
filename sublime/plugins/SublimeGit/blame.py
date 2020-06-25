import re
import sublime_plugin
import subprocess

from datetime import datetime, timedelta

new_file_regex = re.compile('fatal: no such path \'.*\' in HEAD')
not_git_regex = re.compile('fatal: not a git repository \\(or any of the parent directories\\): .git')
author_regex = re.compile('author\\s(.*)')
time_regex = re.compile('author-time\\s(.*)')
summary_regex = re.compile('summary\\s(.*)')


# From https://gist.github.com/jonlabelle/7d306575cbbd34b154f87b1853d532cc
def relative_time(date):
    def formatn(n, s):
        if n == 1:
            return '1 %s' % s
        elif n > 1:
            return '%d %ss' % (n, s)

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
            return 'just now'

    return FormatDelta(date).format()


class SublimeGitBlame(sublime_plugin.EventListener):
    _blame_key = 'git_blame'

    _last_filename = ''
    _last_linenumber = 0

    def on_selection_modified_async(self, view):
        selections = view.sel()
        if len(selections) > 1:
            view.erase_regions(self._blame_key)
            return

        window = view.window()
        if not window:
            return

        vars = window.extract_variables()
        file_name = vars['file_name']
        line_number = view.rowcol(selections[0].begin())[0] + 1 # index start at 0

        if file_name == self._last_filename and line_number == self._last_linenumber:
            return

        self._last_filename = file_name
        self._last_linenumber = line_number

        working_dir = vars['file_path']

        try:
            git_blame = subprocess.check_output(['git', 'blame', '-p', '-L', '{},{}'.format(line_number, line_number), '--', file_name], stderr=subprocess.STDOUT, cwd=working_dir)
        except subprocess.CalledProcessError as e:
            err_content = e.output.decode('utf8')
            if not new_file_regex.match(err_content) and not not_git_regex.match(err_content):
                print(err_content, end='')
            return

        blame_content = git_blame.decode('utf8')
        author = author_regex.findall(blame_content)[0]
        if author == 'Not Committed Yet':
            view.erase_regions(self._blame_key)
            return

        moment = datetime.fromtimestamp(int(time_regex.findall(blame_content)[0]))
        description = summary_regex.findall(blame_content)[0]
        blame = '<strong>{}</strong> <em>{}</em> {}'.format(author, relative_time(moment), description)

        view.add_regions(self._blame_key, [selections[0]], annotations=[blame], annotation_color="royalblue")
