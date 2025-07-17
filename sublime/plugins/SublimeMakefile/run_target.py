import re
import subprocess
import threading

import sublime_plugin

import sublime

from .async_task import AsyncTask

target_regex = re.compile("^[a-z].*:$")


class MakefileTarget(sublime_plugin.ListInputHandler):
    def __init__(self, window):
        self.window = window

    def name(self):
        return "makefile_target"

    def list_items(self):
        variables = self.window.extract_variables()
        working_dir = variables.get("file_path")

        targets = []

        for line in subprocess.run(
            [
                "make",
                "--question",
                "--print-data-base",
                "--no-builtin-variables",
                "--no-builtin-rules",
            ],
            capture_output=True,
            text=True,
            cwd=working_dir,
        ).stdout.splitlines():
            if target_regex.match(line):
                targets.append(line[:-1])

        return targets


class MakefileRun(sublime_plugin.WindowCommand):
    task = None
    panel = None

    def input(self, args):
        if "kill" in args:
            return None

        return MakefileTarget(self.window)

    def is_enabled(self, kill=False):
        if kill:
            return self.task is not None and self.task.enabled(kill=kill)

        return True

    def run(self, makefile_target, kill=False):
        if kill:
            if self.task:
                self.task.kill()

            return

        window = self.window
        if not window:
            return

        variables = window.extract_variables()
        working_dir = variables.get("file_path")

        self.panel = window.create_output_panel("make")
        settings = self.panel.settings()
        settings.set("result_file_regex", r"([^\s[]+?):(\d+)")
        settings.set("result_base_dir", working_dir)
        window.run_command("show_panel", {"panel": "output.make"})

        if self.task:
            self.task.kill()

        self.task = AsyncTask(
            command=[
                "make",
                makefile_target,
            ],
            output=self.queue_write,
            cwd=working_dir,
        )

    def queue_write(self, text):
        sublime.set_timeout(lambda: self.do_write(text), 1)

    def do_write(self, text):
        self.panel.run_command("append", {"characters": text})
