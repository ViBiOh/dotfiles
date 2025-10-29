import sublime_plugin

import sublime

from .async_task import AsyncTask


class SublimeGitLineHistory(sublime_plugin.WindowCommand):
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
        folder = variables.get("folder")
        file = variables.get("file")

        if not file or len(file) == 0:
            return

        view = window.active_view()
        start_line = view.rowcol(view.sel()[0].begin())[0] + 1
        end_line = view.rowcol(view.sel()[0].end())[0] + 1

        relative_file = file.replace(folder, "").lstrip("/")

        self.panel = window.create_output_panel("line_history")
        window.run_command("show_panel", {"panel": "output.line_history"})

        if self.task:
            self.task.kill()

        self.task = AsyncTask(
            command=[
                "git",
                "log-pretty",
                "--no-color",
                "-L",
                "{},{}:{}".format(start_line, end_line, relative_file),
            ],
            output=self.queue_write,
            cwd=folder,
        )

    def queue_write(self, text):
        sublime.set_timeout(lambda: self.do_write(text), 1)

    def do_write(self, text):
        self.panel.run_command("append", {"characters": text})
