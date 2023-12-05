import sublime
import sublime_plugin


class SublimeGitLinepath(sublime_plugin.WindowCommand):
    def run(self):
        window = self.window
        if not window:
            return

        variables = window.extract_variables()
        folder = variables.get("folder")
        file = variables.get("file")

        if not file or len(file) == 0:
            return

        view = window.active_view()
        line_number = view.rowcol(view.sel()[0].begin())[0] + 1

        relative_file = file.replace(folder, "").lstrip("/")

        url = "{}:{}".format(relative_file, line_number)

        sublime.set_clipboard(url)
