import subprocess
import threading

import sublime_plugin

import sublime

PLUGIN_NAME = "Formatter"
PLUGIN_SETTINGS = "{}.sublime-settings".format(PLUGIN_NAME)


def plugin_loaded() -> None:
    global _settings_obj
    loaded_settings_obj = sublime.load_settings(PLUGIN_SETTINGS)
    _settings_obj = loaded_settings_obj


def format(view, region, working_dir, commands):
    value = view.substr(region)

    for command in commands:
        process = subprocess.Popen(
            command,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )

        timeout = threading.Timer(interval=5, function=process.terminate)
        timeout.start()

        try:
            process_out, process_err = process.communicate(value.encode("utf8"))

            error = process_err.decode("utf8")
            if process.returncode != 0 or len(error) > 0:
                print(error, end="")
                return value

            value = process_out.decode("utf8")

        finally:
            if timeout.is_alive():
                timeout.cancel()

    return value


def get_allowed_selectors(file):
    if not file:
        return None

    format_on_save = _settings_obj.get("format_on_save")
    if format_on_save == "all":
        return None

    return format_on_save.split(",")


def get_commands(view, point, commands):
    for selector in commands:
        if view.match_selector(point, selector):
            return commands[selector]

    return []


def get_regions(view, file):
    if file:
        return [sublime.Region(0, view.size())]

    regions = view.sel()
    if len(regions) == 1 and regions[0].a == regions[0].b:
        return [sublime.Region(0, view.size())]

    return regions


class FormatterDisableOnSave(sublime_plugin.WindowCommand):
    def run(self):
        _settings_obj.set("format_on_save", "")


class FormatterEnableOnSave(sublime_plugin.WindowCommand):
    def run(self):
        _settings_obj.set("format_on_save", "all")


class command(sublime_plugin.TextCommand):
    def run(self, edit, file=False):
        view = self.view

        window = view.window()
        if not window:
            return

        variables = window.extract_variables()
        working_dir = variables.get("file_path")

        for region in get_regions(view, file):
            view.replace(edit, region, self.format(view, file, region, working_dir))


class Formatter(command):
    def __init__(self, view):
        self.view = view

    def format(self, view, file, region, working_dir):
        allowed_selectors = get_allowed_selectors(file)

        selectors = {}
        for selector, commands in _settings_obj.get("selectors", {}).items():
            if allowed_selectors is None or selector in allowed_selectors:
                selectors[selector] = commands

        commands = get_commands(view, region.a, selectors)
        return format(view, region, working_dir, commands)


class CompactJson(command):
    def format(self, view, file, region, working_dir):
        return format(
            view,
            region,
            working_dir,
            [
                ["jq", "--compact-output"],
            ],
        )


class CompactYaml(command):
    def format(self, view, file, region, working_dir):
        return format(
            view,
            region,
            working_dir,
            [
                ["yq", "--prettyPrint", "--no-colors"],
            ],
        )


class SublimeFormatOnSave(sublime_plugin.EventListener):
    def on_pre_save(self, view):
        view.run_command("formatter", {"file": True})
