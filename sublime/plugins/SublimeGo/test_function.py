import sublime
import sublime_plugin
import threading
from .async_task import AsyncTask
from .env_loader import load_git_root_env


class GoFunctionTest(sublime_plugin.WindowCommand):
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

        function_name = self.get_function_name(window)

        self.queue_write("Running go test for {}...\n".format(function_name))

        self.task = AsyncTask(
            command=["go", "test", ".", "-cover", "-race", "-run", function_name],
            output=self.queue_write,
            cwd=working_dir,
            env=load_git_root_env(working_dir),
        )

    def queue_write(self, text):
        sublime.set_timeout(lambda: self.do_write(text), 1)

    def do_write(self, text):
        self.panel.run_command("append", {"characters": text})

    def get_function_name(self, window):
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
