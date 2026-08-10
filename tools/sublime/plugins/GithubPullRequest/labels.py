"""Conventional Comments (https://conventionalcomments.org) labels for the
add-comment picker.

The label set itself lives in GithubPullRequest.sublime-settings (`comment_labels`), which
is the only copy: load_settings merges it under any User override, so a default here would
just be a second one to keep in sync. The optional `emoji` shows in the picker and is
prefixed to the posted comment; drop it to get a plain `label: subject`."""

from typing import Dict


def label_tag(entry: Dict) -> str:
    """'💡 suggestion' when the label carries an emoji, else 'suggestion'."""
    emoji = entry.get("emoji", "")
    label = entry["label"]

    return f"{emoji} {label}" if emoji else label
