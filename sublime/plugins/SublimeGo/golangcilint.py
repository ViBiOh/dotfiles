from SublimeLinter.lint import WARNING, Linter


class GolangCILint(Linter):
    regex = (
        r"^(?P<filename>(?:\w:)?[^:]+):"
        # Column reporting is optional and not provided by all linters.
        r"(?P<line>\d+)(?::(?P<col>\d+))?:*\s+"
        r"(?P<message>.+?)"
        # Issues reported by the 'typecheck' linter are treated as errors,
        # because they indicate code that won't compile.
        r"(?:\s+\((?:(?P<error>typecheck)|(?P<code>[^()]+))\))?$"
    )

    # All other linter issues are treated as warnings.
    default_type = WARNING
    defaults = {
        "selector": "source.go",
    }

    tempfile_suffix = "-"

    def cmd(self):
        view = self.view
        if not view:
            return "true ${file_path}"

        window = view.window()
        if not window:
            return "true ${file_path}"

        variables = window.extract_variables()
        folder = variables.get("folder")
        file = variables.get("file")

        if not file.startswith(folder):
            return "true ${file_path}"

        return "golangci-lint run --fix --allow-parallel-runners ${file_path}"
