import sublime
import sublime_plugin
import threading
from . async_task import AsyncTask


class GoTest(sublime_plugin.WindowCommand):
    task = None
    panel = None
    panel_lock = threading.Lock()

    def is_enabled(self, kill=False):
        if self.task:
            return self.task.enabled()

        return True

    def run(self, kill=False):
        if kill:
            if self.task:
                self.task.kill()

            return

        vars = self.window.extract_variables()
        working_dir = vars['file_path']

        with self.panel_lock:
            self.panel = self.window.create_output_panel('gotest')
            self.window.run_command('show_panel', {'panel': 'output.gotest'})

        self.queue_write('Running go test...\n')

        self.task = AsyncTask(command=['go', 'test', '-cover', '-race'], output=self.queue_write, cwd=working_dir)

    def queue_write(self, text):
        sublime.set_timeout(lambda: self.do_write(text), 1)

    def do_write(self, text):
        with self.panel_lock:
            self.panel.run_command('append', {'characters': text})
