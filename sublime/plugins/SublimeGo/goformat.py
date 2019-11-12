import sublime
import sublime_plugin
import subprocess


class GoFormat(sublime_plugin.TextCommand):
    def run(self, edit):
        view = self.view
        if not view.match_selector(0, 'source.go'):
            return

        region = sublime.Region(0, view.size())
        src = view.substr(region)

        vars = view.window().extract_variables()
        working_dir = vars['file_path']

        goimports = subprocess.Popen(['goimports'], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=working_dir)
        goimports_out, goimports_err = goimports.communicate(src.encode())
        if goimports.returncode != 0:
            print(goimports_err.decode(), end="")
            return

        gofmt = subprocess.Popen(['gofmt', '-s'], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        gofmt_out, gofmt_err = gofmt.communicate(goimports_out)
        if goimports.returncode != 0:
            print(gofmt_err.decode(), end="")
            return

        view.replace(edit, region, gofmt_out.decode())


class GoformatOnSave(sublime_plugin.EventListener):
    def on_pre_save(self, view):
        view.run_command('go_format')
