import sublime_plugin


class SplitVertically(sublime_plugin.TextCommand):
    def run(self, edit):
        window = self.view.window()

        window.set_layout(
            {
                "cols": [0.0, 0.5, 1.0],
                "rows": [0.0, 1.0],
                "cells": [[0, 0, 1, 1], [1, 0, 2, 1]],
            }
        )
        window.run_command("focus_group", {"group": 0})
        window.run_command("move_to_group", {"group": 1})


class ResetLayout(sublime_plugin.TextCommand):
    def run(self, edit):
        window = self.view.window()

        window.set_layout(
            {"cols": [0.0, 1.0], "rows": [0.0, 1.0], "cells": [[0, 0, 1, 1]]}
        )
