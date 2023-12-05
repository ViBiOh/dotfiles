import sublime
import sublime_plugin


class SublimeGitLinepath(sublime_plugin.WindowCommand):
    def run(self):
        window = self.window
        if not window:
            return

        variables = window.extract_variables()
        folder = variables.get("folder")
        file_path = variables.get("file_path")

        if not file_path or len(file_path) == 0:
            return

        view = window.active_view()
        line_number = view.rowcol(view.sel()[0].begin())[0] + 1

        relative_file_path = file_path.replace(folder, "").lstrip("/")

        url = "{}:{}".format(relative_file_path, line_number)

        sublime.set_clipboard(url)
