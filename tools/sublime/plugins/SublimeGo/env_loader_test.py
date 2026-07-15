import unittest

try:
    from .env_loader import parse_env
except ImportError:
    from env_loader import parse_env


class ParseEnvTest(unittest.TestCase):
    def test_parse_env(self):
        cases = {
            "simple": ("FOO=bar\n", {"FOO": "bar"}),
            "export prefix": ("export FOO=bar\n", {"FOO": "bar"}),
            "spaces around equal": ("FOO = bar\n", {"FOO": "bar"}),
            "full line comment": ("# a comment\nFOO=bar\n", {"FOO": "bar"}),
            "inline comment": ("FOO=bar # trailing\n", {"FOO": "bar"}),
            "hash inside value": ("FOO=a#b\n", {"FOO": "a#b"}),
            "trailing whitespace": ("FOO=bar   \n", {"FOO": "bar"}),
            "empty value": ("FOO=\n", {"FOO": ""}),
            "single quoted": ("FOO='a b c'\n", {"FOO": "a b c"}),
            "single quote literal dollar": ("FOO='$(whoami)'\n", {"FOO": "$(whoami)"}),
            "double quoted": ('FOO="a b"\n', {"FOO": "a b"}),
            "double quote no command substitution": (
                'FOO="$(whoami)"\n',
                {"FOO": "$(whoami)"},
            ),
            "double quote literal backtick": ('FOO="`whoami`"\n', {"FOO": "`whoami`"}),
            "double quote escaped quote": (
                'FOO="he said \\"hi\\""\n',
                {"FOO": 'he said "hi"'},
            ),
            "double quote escaped dollar": ('FOO="\\$HOME"\n', {"FOO": "$HOME"}),
            "backslash kept literal": ('FOO="a\\nb"\n', {"FOO": "a\\nb"}),
            "multiline single quoted": (
                "FOO='line1\nline2'\n",
                {"FOO": "line1\nline2"},
            ),
            "multiline double quoted": (
                'FOO="line1\nline2"\n',
                {"FOO": "line1\nline2"},
            ),
            "line continuation": ('FOO="a\\\nb"\n', {"FOO": "ab"}),
            "multiple variables": ("A=1\nB=2\n", {"A": "1", "B": "2"}),
            "blank lines ignored": ("\n\nA=1\n\n", {"A": "1"}),
            "malformed line skipped": ("not a var line\nA=1\n", {"A": "1"}),
            "later value overrides earlier": ("A=1\nA=2\n", {"A": "2"}),
            "crlf unquoted trimmed": ("FOO=bar\r\n", {"FOO": "bar"}),
            "crlf quoted": ('FOO="bar"\r\n', {"FOO": "bar"}),
            "unterminated double quote": ('FOO="bar\n', {"FOO": "bar\n"}),
            "value with equals signs": ("FOO=a=b=c\n", {"FOO": "a=b=c"}),
            "leading digit key skipped": ("1AB=2\nA=1\n", {"A": "1"}),
        }

        for name, (source, want) in cases.items():
            with self.subTest(name=name):
                self.assertEqual(parse_env(source), want)


if __name__ == "__main__":
    unittest.main()
