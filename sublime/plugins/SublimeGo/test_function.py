import os
import threading

import sublime_plugin

import sublime

from .async_task import AsyncTask
from .env_loader import load_git_root_env


class GoFunctionTestInput(sublime_plugin.TextInputHandler):
    def __init__(self, window, previous):
        self.window = window
        self.previous = previous

    def name(self):
        return "test_filter"

    def description(self):
        return "Filter"

    def initial_text(self):
        if not self.window:
            return "Test*"

        current_function = self._get_function_name()
        if self.previous and self.previous.startswith(current_function):
            return self.previous

        return current_function

    def _get_function_name(self):
        view = self.window.active_view()

        current_point = view.sel()[0].begin()
        current_function = ""

        for function_symbol in [
            x for x in view.symbol_regions() if x.kind[0] == sublime.KIND_ID_FUNCTION
        ]:
            if function_symbol.region.begin() < current_point:
                current_function = function_symbol.name
            else:
                return current_function

        return current_function


class GoFunctionTest(sublime_plugin.WindowCommand):
    task = None
    panel = None
    previous_filter = ""

    def input(self, args):
        return GoFunctionTestInput(self.window, self.previous_filter)

    def is_enabled(self, kill=False):
        if kill:
            return self.task is not None and self.task.enabled(kill=kill)

        return True

    def run(self, test_filter, kill=False):
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

        self.previous_filter = test_filter

        self.task = AsyncTask(
            command=[
                "go",
                "test",
                "-cover",
                "-race",
                "-count=1",
                "-timeout=30s",
                "-run",
                test_filter,
            ],
            output=self.queue_write,
            cwd=working_dir,
            env=load_git_root_env(working_dir),
        )

    def queue_write(self, text):
        sublime.set_timeout(lambda: self.do_write(text), 1)

    def do_write(self, text):
        self.panel.run_command("append", {"characters": text})
