import os
import threading

import sublime_plugin

import sublime

from .async_task import AsyncTask
from .env_loader import load_git_root_env


class GoTest(sublime_plugin.WindowCommand):
    task = None
    panel = None

    def is_enabled(self, kill=False):
        if kill:
            return self.task is not None and self.task.enabled(kill=kill)

        return True

    def run(self, kill=False):
        if kill:
            if self.task:
                self.task.kill()

            return

        window = self.window
        if not window:
            return

        variables = window.extract_variables()
        working_dir = variables.get("file_path")

        self.panel = window.create_output_panel("gotest")
        settings = self.panel.settings()
        settings.set("result_file_regex", r"([^\s[]+?):(\d+)")
        settings.set("result_base_dir", working_dir)
        window.run_command("show_panel", {"panel": "output.gotest"})

        if self.task:
            self.task.kill()

        self.task = AsyncTask(
            command=["go", "test", "-cover", "-race", "-count=1", "-timeout=30s"],
            output=self.queue_write,
            cwd=working_dir,
            env=load_git_root_env(working_dir),
        )

    def queue_write(self, text):
        sublime.set_timeout(lambda: self.do_write(text), 1)

    def do_write(self, text):
        self.panel.run_command("append", {"characters": text})
