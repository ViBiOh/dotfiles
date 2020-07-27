import sublime
import sublime_plugin
import subprocess


CONFIGURATIONS = {
    'source.terraform': [
        ['terraform', 'fmt', '-'],
    ],
    'source.go': [
        ['goimports'],
        ['gofmt', '-s'],
    ],
    'source.json': [
        ['prettier', '--stdin-filepath', 'file.json'],
    ],
    'source.yaml': [
        ['prettier', '--stdin-filepath', 'file.yml'],
    ],
    'text.html.markdown': [
        ['prettier', '--stdin-filepath', 'file.md'],
    ],
}


class SublimeFormat(sublime_plugin.TextCommand):
    def run(self, edit):
        view = self.view

        window = view.window()
        if not window:
            return

        commands = []
        for selector in CONFIGURATIONS:
            if view.match_selector(0, selector):
                commands = CONFIGURATIONS[selector]
                break

        if len(commands) == 0:
            return

        region = sublime.Region(0, view.size())
        src = view.substr(region)

        variables = window.extract_variables()
        working_dir = variables['file_path']

        value = src
        for command in commands:
            process = subprocess.Popen(command,
                                       stdin=subprocess.PIPE,
                                       stdout=subprocess.PIPE,
                                       stderr=subprocess.PIPE,
                                       cwd=working_dir)

            process_out, process_err = process.communicate(value.encode())
            if process.returncode != 0:
                print(process_err.decode(), end='')
                return

            value = process_out.decode()

        view.replace(edit, region, value)


class SublimeFormatOnSave(sublime_plugin.EventListener):
    def on_pre_save(self, view):
        view.run_command('sublime_format')
