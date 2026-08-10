"""`label_tag`, plus a check on the packaged settings file that supplies the labels.

The default label set used to be duplicated in labels.py; now the settings file is the
only copy, so it is what has to be well-formed. Sublime settings are JSON with `//`
comments, which json cannot parse, so the comment lines are stripped first (they are
always whole lines here, never trailing, so no string value can be truncated)."""

import json
import os
import re
import unittest

try:
    from .labels import label_tag
except ImportError:
    from labels import label_tag

_HERE = os.path.dirname(os.path.abspath(__file__))
_SETTINGS = os.path.join(_HERE, "GithubPullRequest.sublime-settings")

_COMMENT_LINE_RE = re.compile(r"^\s*//.*$", re.MULTILINE)


def _packaged_settings():
    with open(_SETTINGS, encoding="utf-8") as handle:
        raw = handle.read()

    return json.loads(_COMMENT_LINE_RE.sub("", raw))


class LabelTagTest(unittest.TestCase):
    def test_tag(self):
        cases = {
            "with_emoji": ({"emoji": "💡", "label": "suggestion"}, "💡 suggestion"),
            "without_emoji": ({"label": "suggestion"}, "suggestion"),
            "empty_emoji": ({"emoji": "", "label": "note"}, "note"),
        }

        for name, (entry, expected) in cases.items():
            with self.subTest(name):
                self.assertEqual(label_tag(entry), expected)


class PackagedSettingsTest(unittest.TestCase):
    def setUp(self):
        self.settings = _packaged_settings()

    def test_comment_labels_are_well_formed(self):
        labels = self.settings["comment_labels"]

        self.assertTrue(labels)

        for entry in labels:
            with self.subTest(entry.get("label")):
                self.assertIn("label", entry)
                self.assertIn("description", entry)
                self.assertTrue(label_tag(entry))

    def test_ships_the_defaults_the_plugin_reads(self):
        # plugin.py no longer carries fallbacks for these, so a missing key here would
        # silently disable the label picker or the agent command.
        for key in (
            "auto_show_popup",
            "show_gutter_icon",
            "hide_outdated",
            "gutter_icon",
            "conventional_comments",
            "comment_labels",
            "agent_command",
            "agent_review_prompt",
        ):
            with self.subTest(key):
                self.assertIn(key, self.settings)

    def test_agent_command_is_a_list(self):
        self.assertIsInstance(self.settings["agent_command"], list)
        self.assertTrue(self.settings["agent_command"])

    def test_agent_prompt_only_interpolates_base(self):
        # The prompt goes through str.format, so every brace in it must be the {base}
        # placeholder or the launch fails at format time.
        prompt = self.settings["agent_review_prompt"]

        self.assertIn("{base}", prompt)
        self.assertEqual(set(re.findall(r"\{(\w*)\}", prompt)), {"base"})
        self.assertTrue(prompt.format(base="main"))


if __name__ == "__main__":
    unittest.main()
