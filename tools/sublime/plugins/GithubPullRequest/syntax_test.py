"""Guards the files-panel styling, which is split across two files that reference each
other only by string and would fail SILENTLY if they drifted apart: `panel.py` emits the
open-file marker, and `GithubPullRequestFiles.sublime-syntax` matches that glyph to grey
the row's marker and path.

Stdlib only (no PyYAML on the Sublime host), so the syntax is scraped with regexes rather
than parsed as YAML. That is enough to catch a renamed scope or a changed marker."""

import os
import re
import unittest

try:
    from . import panel
except ImportError:
    import panel

_HERE = os.path.dirname(os.path.abspath(__file__))
_SYNTAX = os.path.join(_HERE, "GithubPullRequestFiles.sublime-syntax")

_MATCH_RE = re.compile(r"^\s*-\s*match:\s*(.+?)\s*$", re.MULTILINE)
_SCOPE_RE = re.compile(r"^\s*(?:scope|\d+):\s*(\S+)\s*$", re.MULTILINE)


def _read(path):
    with open(path, encoding="utf-8") as handle:
        return handle.read()


def _patterns(text):
    """Every `- match:` pattern, unquoted."""
    out = []
    for raw in _MATCH_RE.findall(text):
        if len(raw) >= 2 and raw[0] == raw[-1] and raw[0] in "'\"":
            raw = raw[1:-1]
        out.append(raw)

    return out


class SyntaxTest(unittest.TestCase):
    def setUp(self):
        self.syntax = _read(_SYNTAX)

    def test_every_match_pattern_compiles(self):
        patterns = _patterns(self.syntax)

        self.assertGreater(len(patterns), 5, "scraping found suspiciously few rules")

        for pattern in patterns:
            with self.subTest(pattern):
                try:
                    re.compile(pattern)
                except re.error as err:
                    # Sublime matches with Oniguruma, a superset of Python's `re`. If a
                    # rule deliberately uses an Oniguruma-only construct (`\x{HHHH}`,
                    # `\h`, ...), translate it here rather than dropping the check.
                    self.fail(f"{pattern!r} is not a valid regex: {err}")

    def test_matches_the_marker_panel_actually_emits(self):
        glyph = panel._OPEN_MARKER.strip()

        self.assertTrue(glyph, "the open marker needs a glyph for the syntax to match")
        self.assertIn(
            f"'^{glyph}'",
            self.syntax,
            "the syntax no longer anchors on panel._OPEN_MARKER, so open rows lose "
            "their grey silently",
        )

    def test_marker_slots_are_the_same_width(self):
        # The marker is visible, so the closed rows need a blank slot of equal width or
        # the path column shifts on open rows only.
        self.assertEqual(len(panel._OPEN_MARKER), len(panel._CLOSED_MARKER))
        self.assertEqual(panel._CLOSED_MARKER.strip(), "")

    def test_stats_rule_cannot_match_a_hyphen_inside_a_path(self):
        # The `+N -M` rule lost its `^` anchor when the marker slot was added, so this is
        # the regression that would silently repaint parts of file names red. The paths
        # below are the dangerous shape: a hyphen followed by digits.
        stats = re.compile(next(p for p in _patterns(self.syntax) if r"\+\d+" in p))

        cases = {
            "notes_row_hyphen_digit_path": "●     (1 unresolved)      pkg/v2-3.py:12",
            "file_row_hyphen_digit_path": "  +2 -0                    pkg/v2-3.py:1",
            "owners_with_hyphen_digits": "  +2 -0                    a.py:1  @team-2",
        }

        for name, row in cases.items():
            with self.subTest(name):
                found = stats.findall(row)
                # The only legal match is the row's own leading "+N -M" pair.
                self.assertIn(len(found), (0, 1), found)
                for plus, minus in found:
                    self.assertEqual((plus, minus), ("+2", "-0"), row)

    def test_open_row_is_grey_by_inheritance(self):
        # Greying an already-visited row relies ENTIRELY on its scopes living under
        # `comment.`, which every color scheme renders dimmed. Move one out from under
        # `comment.` and that token silently takes the default foreground instead.
        scopes = _SCOPE_RE.findall(self.syntax)
        open_scopes = [scope for scope in scopes if "open-file" in scope]

        # the marker and the path token
        self.assertEqual(len(open_scopes), 2, scopes)

        for scope in open_scopes:
            with self.subTest(scope):
                self.assertTrue(scope.startswith("comment."), scope)

    def test_no_scope_needs_a_color_scheme_override(self):
        # font_style (italic/bold) is the only thing a syntax cannot express, and it is no
        # longer used, so the package must not ship a color-scheme override to maintain.
        overrides = [
            name for name in os.listdir(_HERE) if name.endswith(".sublime-color-scheme")
        ]

        self.assertEqual(overrides, [])


if __name__ == "__main__":
    unittest.main()
