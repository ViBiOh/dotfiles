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
        tmp.close()

        def task():
            try:
                result = subprocess.run(
                    [
                        "pandoc",
                        "--from=gfm",
                        "--to=html",
                        "--standalone",
                        "--strip-comments",
                        "--embed-resources",
                        "--include-in-header",
                        os.path.join(
                            sublime.packages_path(), "SublimeMarkdown", "mermaid.html"
                        ),
                        "--output",
                        tmp.name,
                        file,
                    ],
                    cwd=working_dir,
                    capture_output=True,
                )
            except FileNotFoundError as err:
                print("unable to run pandoc: {}".format(err))
                os.unlink(tmp.name)
                return

            if result.returncode != 0:
                print(result.stderr.decode("utf8", errors="replace"), end="")
                os.unlink(tmp.name)
                return

            webbrowser.open("file://" + tmp.name)
            sublime.set_timeout(lambda: os.unlink(tmp.name), 30000)

        threading.Thread(target=task).start()
