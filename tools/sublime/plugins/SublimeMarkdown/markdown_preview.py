import os
import subprocess
import tempfile
import threading
import webbrowser

import sublime
import sublime_plugin


class MarkdownPreview(sublime_plugin.WindowCommand):
    def run(self):
        window = self.window
        if not window:
            return

        variables = window.extract_variables()
        working_dir = variables.get("file_path")
        file = variables.get("file")

        tmp = tempfile.NamedTemporaryFile(
            suffix=".html", prefix="md-preview-", delete=False
        )
        tmp_path = tmp.name
        tmp.close()

        def task():
            subprocess.run(
                [
                    "pandoc",
                    "--from=gfm",
                    "--to=html",
                    "--include-after-body",
                    sublime.packages_path() + "/SublimeMarkdown/mermaid.html",
                    "--output",
                    tmp_path,
                    file,
                ],
                cwd=working_dir,
            )

            webbrowser.open("file://" + tmp_path)
            sublime.set_timeout(lambda: os.unlink(tmp_path), 5000)

        threading.Thread(target=task).start()
