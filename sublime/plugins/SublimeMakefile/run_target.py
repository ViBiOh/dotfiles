import threading

import sublime_plugin

import sublime

from .async_task import AsyncTask


class MakefileRun(sublime_plugin.WindowCommand):
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

        self.panel = window.create_output_panel("make")
        settings = self.panel.settings()
        settings.set("result_file_regex", r"([^\s[]+?):(\d+)")
        settings.set("result_base_dir", working_dir)
        window.run_command("show_panel", {"panel": "output.make"})

        if self.task:
            self.task.kill()

        function_name = self.get_target_name(window)
        function_name = function_name.split(" ")[0]

        self.task = AsyncTask(
            command=[
                "make",
                function_name,
            ],
            output=self.queue_write,
            cwd=working_dir,
        )

    def queue_write(self, text):
        sublime.set_timeout(lambda: self.do_write(text), 1)

    def do_write(self, text):
        self.panel.run_command("append", {"characters": text})

    def get_target_name(self, window):
        view = window.active_view()

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
