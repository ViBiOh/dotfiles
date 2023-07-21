import sublime
import sublime_plugin
import threading
from .async_task import AsyncTask
from .env_loader import load_env


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

        env = load_env(working_dir)

        if self.task:
            self.task.kill()

        self.queue_write("Running go test...\n")

        self.task = AsyncTask(
            command=["go", "test", "-cover", "-race"],
            output=self.queue_write,
            cwd=working_dir,
            env=env,
        )

    def queue_write(self, text):
        sublime.set_timeout(lambda: self.do_write(text), 1)

    def do_write(self, text):
        self.panel.run_command("append", {"characters": text})
