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
        return "golangci-lint run --fix ${file_path}"
