import hashlib
import html
import re
import subprocess
import threading
from datetime import datetime

import sublime
import sublime_plugin

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
filename_regex = re.compile("^filename\\s(?P<filename>.*)")


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


def parse_git_blame(blame):
    lines = {}
    original_lines = {}
    commits = {}

    current_sha = ""
    current_commit = None

    for line in blame.splitlines():
        line_match = line_regex.match(line)
        if line_match:
            if current_commit:
                commits[current_commit.get("sha")] = current_commit

            current_sha = line_match.group("sha")
            final_line = int(line_match.group("final_line"))

            lines[final_line] = current_sha
            original_lines[final_line] = line_match.group("origin_line")

            current_commit = commits.get(current_sha) or {"sha": current_sha}

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

        filename_match = filename_regex.match(line)
        if filename_match:
            current_commit["filename"] = filename_match.group("filename")
            continue

    if current_commit:
        commits[current_commit.get("sha")] = current_commit

    return {
        "lines": lines,
        "original_lines": original_lines,
        "commits": commits,
    }


class SublimeGitDisableBlame(sublime_plugin.WindowCommand):
    def run(self):
        _settings_obj.set("show_blame", False)
        for window in sublime.windows():
            for view in window.views():
                view.erase_regions(SublimeGitBlame._status_key)


class SublimeGitEnableBlame(sublime_plugin.WindowCommand):
    def run(self):
        _settings_obj.set("show_blame", True)


class SublimeGitBlame(sublime_plugin.EventListener):
    _status_key = "git_blame"

    def __init__(self):
        super().__init__()

        self._lock = threading.Lock()

        self._git_info = {}
        self._git_blame = None
        self._git_remote = ""

        self._file_name = ""
        self._line_number = 0

    def clear_status(self, view):
        view.erase_regions(self._status_key)

    def print_status(self, view, selection, author, moment, description, url):
        content = '<a href="{}">{}</a> <span style="color: var(--{})">({})</span> <span style="color: var(--{})">&lt;{}&gt;</span>'.format(
            html.escape(url),
            html.escape(description or ""),
            "greenish",
            relative_time(moment),
            "purplish",
            html.escape(author or ""),
        )

        view.add_regions(
            self._status_key,
            [selection],
            self._status_key,
            flags=sublime.HIDDEN | sublime.PERSISTENT,
            annotations=[content],
            annotation_color="coral",
        )

    def refresh_file(self, view, force):
        file_name = view.file_name()
        if not file_name or len(file_name) == 0:
            with self._lock:
                self._file_name = ""
                self._git_blame = None
            return

        with self._lock:
            if not force and self._file_name == file_name:
                return

        git_info = git_path(file_name)
        if not git_info:
            with self._lock:
                self._file_name = file_name
                self._line_number = 0
                self._git_blame = None
            return

        git_remote_url = git_remote(git_info["root"])

        try:
            git_blame_output = subprocess.check_output(
                [
                    "git",
                    "blame",
                    "--porcelain",
                    "--",
                    git_info["path"],
                ],
                stderr=subprocess.STDOUT,
                cwd=git_info["root"],
                timeout=10,
            )

            git_blame = parse_git_blame(git_blame_output.decode("utf8"))
        except (FileNotFoundError, subprocess.TimeoutExpired) as err:
            git_blame = None
            print("unable to run git blame: {}".format(err))
        except subprocess.CalledProcessError as e:
            git_blame = None

            err = e.output.decode("utf8")
            if not (new_file_regex.match(err) or not_git_regex.match(err)):
                print(err, end="")

        with self._lock:
            self._file_name = file_name
            self._line_number = 0
            self._git_info = git_info
            self._git_remote = git_remote_url
            self._git_blame = git_blame

    def _is_enabled(self):
        return _settings_obj.get("show_blame", False)

    def on_post_save_async(self, view):
        if not self._is_enabled():
            return

        self.refresh_file(view, True)
        self.render_current_line(view)

    def on_selection_modified_async(self, view):
        if not self._is_enabled():
            return

        self.refresh_file(view, False)
        self.render_current_line(view)

    def render_current_line(self, view):
        selections = view.sel()
        if len(selections) != 1:
            self.clear_status(view)
            return

        selection = selections[0]

        with self._lock:
            git_blame = self._git_blame
            git_remote_url = self._git_remote
            file_name = self._file_name

        if view.file_name() != file_name:
            # blame for another view was refreshed concurrently, this view's
            # own selection event will fire again once its refresh completes
            return

        if git_blame is None:
            self.clear_status(view)
            return

        current_point = selection.begin()
        line_number = view.rowcol(current_point)[0] + 1  # index start at 0

        with self._lock:
            if line_number == self._line_number:
                return
            self._line_number = line_number

        if line_number != view.rowcol(selection.end())[0] + 1:
            self.clear_status(view)
            return

        if current_point == view.size():
            self.clear_status(view)
            return

        sha = git_blame.get("lines").get(line_number)
        if sha == "0000000000000000000000000000000000000000":
            self.clear_status(view)
            return

        original_line_number = git_blame.get("original_lines").get(line_number)
        if not original_line_number:
            original_line_number = line_number

        commit = git_blame.get("commits").get(sha)
        if not commit:
            return

        filename = commit.get("filename")
        moment = commit.get("time")
        if not filename or not moment:
            self.clear_status(view)
            return

        self.print_status(
            view,
            selection,
            commit.get("author"),
            moment,
            commit.get("summary"),
            "{}/commit/{}#diff-{}R{}".format(
                git_remote_url,
                sha,
                hashlib.sha256(filename.encode("utf8")).hexdigest(),
                original_line_number,
            ),
        )


class SublimeGitDisableCodeowners(sublime_plugin.WindowCommand):
    def run(self):
        _settings_obj.set("show_codeowners", False)
        for window in sublime.windows():
            for view in window.views():
                view.erase_status(SublimeGitCodeowners._status_key)


class SublimeGitEnableCodeowners(sublime_plugin.WindowCommand):
    def run(self):
        _settings_obj.set("show_codeowners", True)


class SublimeGitCodeowners(sublime_plugin.EventListener):
    _status_key = "git_codeowners"

    def __init__(self):
        super().__init__()

        self._lock = threading.Lock()
        self._file_name = ""
        self._git_info = {}

    def clear_status(self, view):
        view.erase_status(self._status_key)

    def print_status(self, view, value):
        view.set_status(self._status_key, value)

    def _is_enabled(self):
        return _settings_obj.get("show_codeowners", True)

    def on_selection_modified_async(self, view):
        if not self._is_enabled():
            return

        file_name = view.file_name()
        if not file_name or len(file_name) == 0:
            return

        with self._lock:
            if file_name == self._file_name:
                return

        git_info = git_path(file_name)
        if not git_info:
            return

        with self._lock:
            self._file_name = file_name
            self._git_info = git_info

        try:
            owners = subprocess.check_output(
                [
                    "codeowners",
                    "--",
                    git_info["path"],
                ],
                stderr=subprocess.STDOUT,
                cwd=git_info["root"],
                timeout=5,
            )

            decoded = owners.decode("utf8").strip()
            if decoded.startswith(git_info["path"]):
                decoded = decoded[len(git_info["path"]) :].strip()

            self.print_status(view, decoded)
        except (FileNotFoundError, subprocess.TimeoutExpired) as err:
            print("unable to run codeowners: {}".format(err))
        except subprocess.CalledProcessError as e:
            print(e.output.decode("utf8"), end="")
