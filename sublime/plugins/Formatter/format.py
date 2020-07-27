import sublime
import sublime_plugin
import subprocess

PLUGIN_NAME = 'Formatter'
PLUGIN_SETTINGS = '{}.sublime-settings'.format(PLUGIN_NAME)


def plugin_loaded() -> None:
    global _settings_obj
    loaded_settings_obj = sublime.load_settings(PLUGIN_SETTINGS)
    _settings_obj = loaded_settings_obj


def format(view, region, working_dir, commands):
    value = view.substr(region)

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

    return value


def get_allowed_selectors(file):
    if not file:
        return None

    format_on_save = _settings_obj.get('format_on_save')
    if format_on_save == 'all':
        return None

    return format_on_save.split(',')


def get_commands(view, point, commands, allowed_selectors):
    for selector in commands:
        if allowed_selectors is not None and selector not in allowed_selectors:
            continue

        if view.match_selector(point, selector):
            return commands[selector]

    return []


class Formatter(sublime_plugin.TextCommand):
    def run(self, edit, file=False):
        view = self.view

        window = view.window()
        if not window:
            return

        variables = window.extract_variables()
        working_dir = variables['file_path']

        commands = _settings_obj.get('commands', {})

        regions = view.sel()
        if file or len(regions) == 1 and regions[0].a == regions[0].b:
            regions = [sublime.Region(0, view.size())]

        allowed_selectors = get_allowed_selectors(file)

        for region in regions:
            region_commands = get_commands(view, region.a, commands, allowed_selectors)
            formatted = format(view, region, working_dir, region_commands)
            view.replace(edit, region, formatted)


class SublimeFormatOnSave(sublime_plugin.EventListener):
    def on_pre_save(self, view):
        view.run_command('formatter', {'file': True})
