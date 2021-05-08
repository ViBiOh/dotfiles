import sublime
import sublime_plugin
import threading
from .async_task import AsyncTask


class GoFunctionTest(sublime_plugin.WindowCommand):
    task = None
    panel = None
    panel_lock = threading.Lock()

    def is_enabled(self, kill=False):
        if self.task:
            return self.task.enabled()

        return True

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

        return ""

    def run(self, kill=False):
        if kill:
            if self.task:
                self.task.kill()

            return

        window = self.window
        if not window:
            return

        variables = window.extract_variables()
        working_dir = variables["file_path"]

        with self.panel_lock:
            self.panel = window.create_output_panel("gotest")
            window.run_command("show_panel", {"panel": "output.gotest"})

        function_name = self.get_function_name(window)

        self.queue_write("Running go test for {}...\n".format(function_name))

        self.task = AsyncTask(
            command=["go", "test", "-cover", "-race", "-run", function_name],
            output=self.queue_write,
            cwd=working_dir,
        )

    def queue_write(self, text):
        sublime.set_timeout(lambda: self.do_write(text), 1)

    def do_write(self, text):
        with self.panel_lock:
            self.panel.run_command("append", {"characters": text})
