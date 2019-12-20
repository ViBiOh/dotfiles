import sublime
import sublime_plugin
import threading


class GoTestDebug(sublime_plugin.WindowCommand):
    panel = None
    panel_lock = threading.Lock()

    def is_enabled(self, kill=False):
        return True

    def run(self, kill=False):
        vars = self.window.extract_variables()
        working_dir = vars['file_path']

        with self.panel_lock:
            self.panel = self.window.create_output_panel('gotestdebug')
            self.window.run_command('show_panel', {'panel': 'output.gotestdebug'})

        self.queue_write('For debugging golang test, run the following command\n\n\tcd {} && dlv test || cd -'.format(working_dir))

    def queue_write(self, text):
        sublime.set_timeout(lambda: self.do_write(text), 1)

    def do_write(self, text):
        with self.panel_lock:
            self.panel.run_command('append', {'characters': text})
