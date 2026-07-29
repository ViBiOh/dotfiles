import sublime
import sublime_plugin

SETTINGS_FILE = "SublimeLinter.sublime-settings"


def _fix_enabled():
    settings = sublime.load_settings(SETTINGS_FILE)
    linters = settings.get("linters") or {}
    golangcilint = linters.get("golangcilint") or {}

    return bool(golangcilint.get("fix", False))


class GolangciLintFixCommand(sublime_plugin.WindowCommand):
    def run(self, enable):
        settings = sublime.load_settings(SETTINGS_FILE)

        linters = dict(settings.get("linters") or {})
        golangcilint = dict(linters.get("golangcilint") or {})

        golangcilint["fix"] = enable
        linters["golangcilint"] = golangcilint
        settings.set("linters", linters)

        sublime.save_settings(SETTINGS_FILE)

        state = "enabled" if enable else "disabled"
        sublime.status_message("golangci-lint --fix " + state)

    def is_visible(self, enable):
        return _fix_enabled() != enable
