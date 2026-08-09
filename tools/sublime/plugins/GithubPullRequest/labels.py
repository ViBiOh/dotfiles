"""Conventional Comments (https://conventionalcomments.org) labels for the
add-comment picker.

Overridable through the `comment_labels` setting. The optional `emoji` shows in the
picker and is prefixed to the posted comment; drop it to get a plain `label: subject`."""

from typing import Dict

DEFAULT_COMMENT_LABELS = [
    {"emoji": "👏", "label": "praise", "description": "highlight something positive"},
    {
        "emoji": "💅",
        "label": "nitpick",
        "description": "trivial, non-blocking preference",
    },
    {"emoji": "💡", "label": "suggestion", "description": "propose a specific change"},
    {"emoji": "⚠️", "label": "issue", "description": "a problem that needs addressing"},
    {"emoji": "📌", "label": "todo", "description": "small, necessary change"},
    {"emoji": "❓", "label": "question", "description": "asking for clarification"},
    {"emoji": "💭", "label": "thought", "description": "a non-blocking idea"},
    {"emoji": "🧹", "label": "chore", "description": "process / housekeeping task"},
    {"emoji": "📝", "label": "note", "description": "an FYI, non-blocking"},
]


def label_tag(entry: Dict) -> str:
    """'💡 suggestion' when the label carries an emoji, else 'suggestion'."""
    emoji = entry.get("emoji", "")
    label = entry["label"]

    return f"{emoji} {label}" if emoji else label
