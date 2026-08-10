import html
import re
import urllib.parse
from html.parser import HTMLParser
from typing import Dict, List, Optional, Tuple

ACTION_PREFIX = "subl:githubpullrequest?"


def _stack(blocks: List[str]) -> str:
    """Join popup blocks with a rule between them: the comments of a thread, the queued
    drafts, or the sections when several land on one line.

    The rule is a `border-top` hung on the FOLLOWING block, never a standalone empty
    <div>. minihtml supports border-top-{width,style,color} but has no `height`, so an
    empty element has no box to draw a border on; putting it on a block that already has
    content sidesteps that. (`<hr>` is not an option at all: minihtml drops it silently.)
    """
    if not blocks:
        return ""

    return blocks[0] + "".join(
        f'<div class="rule">{block}</div>' for block in blocks[1:]
    )


def popup(sections: List[str]) -> str:
    """A full popup document: the stylesheet once, then the sections ruled apart.

    The style must NOT be repeated inside each section, both because it is wasteful and
    because stacking would then nest a <style> element inside a <div>."""
    return build_style() + _stack(sections)


_FENCE_RE = re.compile(r"```([^\n`]*)\n?(.*?)```", re.DOTALL)
_INLINE_CODE_RE = re.compile(r"`([^`]+)`")
# Deliberately as permissive as the `lang == "suggestion"` branch of _FENCE_RE (same
# optional newline, same tolerance for trailing spaces on the fence line). The two must
# agree on how many suggestions a body holds, or the Nth Apply link would apply the
# wrong block.
_SUGGESTION_RE = re.compile(r"```suggestion[^\S\n]*\n?(.*?)```", re.DOTALL)

# GitHub returns comment bodies as rendered HTML (bodyHTML). minihtml only speaks a
# small subset of HTML, so we down-convert: keep the tags below (remapping a few to
# equivalents), drop the rest while keeping their text, and neutralize everything
# else (scripts, styles, images, tables) so nothing renders as raw markup.
_ALLOWED = {
    "p": "p",
    "br": "br",
    "b": "strong",
    "strong": "strong",
    "i": "em",
    "em": "em",
    "code": "code",
    "pre": "pre",
    "blockquote": "blockquote",
    "ul": "ul",
    "ol": "ol",
    "li": "li",
    "a": "a",
    "del": "s",
    "s": "s",
    "span": "span",
    "div": "div",
    "h1": "h1",
    "h2": "h2",
    "h3": "h3",
    "h4": "h4",
    "h5": "h5",
    "h6": "h6",
    "kbd": "kbd",
    "sub": "sub",
    "sup": "sup",
}
_SKIP_CONTENT = {"script", "style"}


def suggestions_in(body: str) -> List[str]:
    """Ordered ```suggestion``` blocks in a raw markdown body. Shared with the
    plugin so the Nth Apply link maps to the Nth applied suggestion."""
    return _SUGGESTION_RE.findall(body or "")


class _MiniHTMLSanitizer(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self._out = []  # type: List[str]
        self._skip = 0
        self._pre = 0

    def handle_starttag(self, tag, attrs):
        if tag in _SKIP_CONTENT:
            self._skip += 1
            return
        if self._skip:
            return

        attributes = dict(attrs)
        if tag == "img":
            self._out.append(html.escape(f"[{attributes.get('alt') or 'image'}]"))
            return
        if tag == "input":
            if attributes.get("type") == "checkbox":
                self._out.append("☑ " if "checked" in attributes else "☐ ")
            return

        mapped = _ALLOWED.get(tag)
        if mapped is None:
            return
        if mapped == "br":
            self._out.append("<br>")
            return
        if mapped == "pre":
            self._pre += 1
        if mapped == "a":
            href = html.escape(attributes.get("href", ""), quote=True)
            self._out.append(f'<a href="{href}">')
            return

        self._out.append(f"<{mapped}>")

    def handle_startendtag(self, tag, attrs):
        self.handle_starttag(tag, attrs)

    def handle_endtag(self, tag):
        if tag in _SKIP_CONTENT:
            if self._skip:
                self._skip -= 1
            return
        if self._skip:
            return

        mapped = _ALLOWED.get(tag)
        if mapped is None or mapped == "br":
            return
        if mapped == "pre" and self._pre:
            self._pre -= 1

        self._out.append(f"</{mapped}>")

    def handle_data(self, data):
        if self._skip:
            return

        escaped = html.escape(data)
        if self._pre:
            escaped = escaped.replace("\n", "<br>")

        self._out.append(escaped)

    def result(self) -> str:
        return "".join(self._out)


def html_to_minihtml(body_html: str) -> str:
    parser = _MiniHTMLSanitizer()
    parser.feed(body_html or "")
    parser.close()

    return parser.result()


def build_style() -> str:
    return (
        "<style>"
        ".author { font-weight: bold; color: var(--bluish); }"
        ".time { color: var(--foreground); }"
        ".body { color: var(--foreground); }"
        ".tag-resolved { color: var(--greenish); }"
        ".tag-outdated { color: var(--yellowish); }"
        ".actions { color: var(--bluish); }"
        ".suggestion { background-color: var(--background); color: var(--greenish); }"
        ".pending-tag { font-weight: bold; color: var(--purplish); }"
        ".rule { border-top-width: 1px; border-top-style: solid;"
        " border-top-color: color(var(--foreground) alpha(0.3));"
        " margin-top: 0.4rem; padding-top: 0.4rem; }"
        "</style>"
    )


def _escape_pre(code: str) -> str:
    return html.escape(code).replace("\n", "<br>")


def _render_text(text: str) -> str:
    escaped = html.escape(text)
    escaped = _INLINE_CODE_RE.sub(
        lambda match: f"<code>{match.group(1)}</code>", escaped
    )
    escaped = escaped.replace("\n", "<br>")

    return f'<div class="body">{escaped}</div>'


def _render_suggestion(code: str, thread_id: str, index: int) -> str:
    href = html.escape(encode_action("apply_suggestion", id=thread_id, sug=index))

    return (
        f'<div class="suggestion">{_escape_pre(code)}<br>'
        f'<a class="actions" href="{href}">Apply</a></div>'
    )


def _render_body(body: str, thread_id: str, sug_counter: List[int]) -> str:
    segments = []  # type: List[str]
    pos = 0

    for match in _FENCE_RE.finditer(body):
        before = body[pos : match.start()]
        if before:
            segments.append(_render_text(before))

        lang = match.group(1).strip()
        code = match.group(2)
        if code.endswith("\n"):
            code = code[:-1]

        if lang == "suggestion":
            segments.append(_render_suggestion(code, thread_id, sug_counter[0]))
            sug_counter[0] += 1
        else:
            segments.append(f'<div class="body"><code>{_escape_pre(code)}</code></div>')

        pos = match.end()

    rest = body[pos:]
    if rest:
        segments.append(_render_text(rest))

    return "".join(segments)


def thread_popup_html(thread: Dict) -> str:
    parts = []

    if thread.get("is_resolved"):
        parts.append('<span class="tag-resolved">resolved</span>')
    if thread.get("is_outdated"):
        parts.append('<span class="tag-outdated">outdated</span>')

    thread_id = thread.get("id")
    sug_counter = [0]

    blocks = []
    for comment in thread.get("comments", []):
        author = html.escape(comment.get("author") or "")
        created = html.escape(comment.get("created_at") or "")
        block = [
            f'<span class="author">{author}</span> <span class="time">{created}</span>'
        ]

        body_html = comment.get("body_html")
        if body_html:
            # Real GitHub data: render the server-rendered HTML, then attach an Apply
            # link per suggestion (extracted from the raw markdown, kept in order).
            block.append(f'<div class="body">{html_to_minihtml(body_html)}</div>')
            for code in suggestions_in(comment.get("body") or ""):
                block.append(_render_suggestion(code, thread_id, sug_counter[0]))
                sug_counter[0] += 1
        else:
            block.append(
                _render_body(comment.get("body") or "", thread_id, sug_counter)
            )

        blocks.append("".join(block))

    # A reply is a separate comment, so rule them apart instead of running them together.
    parts.append(_stack(blocks))

    reply_href = encode_action("reply", id=thread_id)
    if thread.get("is_resolved"):
        toggle_href = encode_action("unresolve", id=thread_id)
        toggle_label = "Unresolve"
    else:
        toggle_href = encode_action("resolve", id=thread_id)
        toggle_label = "Resolve"
    open_href = encode_action("open", url=thread.get("url") or "")

    parts.append(
        '<div class="actions">'
        f'<a href="{html.escape(reply_href)}">Reply</a> '
        f'<a href="{html.escape(toggle_href)}">{toggle_label}</a> '
        f'<a href="{html.escape(open_href)}">Open</a>'
        "</div>"
    )

    return "".join(parts)


def pending_html(drafts: List[Tuple[int, Dict]]) -> str:
    """Popup for locally-queued (not yet posted) review comments. Each item is a
    ``(uid, draft)`` pair; the stable uid drives its Edit / Discard action links."""
    blocks = []
    for uid, draft in drafts:
        edit_href = html.escape(encode_action("edit", uid=uid))
        discard_href = html.escape(encode_action("discard", uid=uid))
        blocks.append(
            _render_text(draft.get("body") or "")
            + '<div class="actions">'
            + f'<a href="{edit_href}">Edit</a> '
            + f'<a href="{discard_href}">Discard</a>'
            + "</div>"
        )

    # Each draft owns its Edit/Discard pair, so they must not run together visually.
    return '<div class="pending-tag">pending review comment</div>' + _stack(blocks)


def draft_badge(count: int) -> str:
    if count == 0:
        return ""

    noun = "draft" if count == 1 else "drafts"

    return f"✎ {count} {noun}"


def encode_action(action: str, **params) -> str:
    parts = [f"action={urllib.parse.quote(str(action))}"]

    for key in sorted(params):
        parts.append(f"{key}={urllib.parse.quote(str(params[key]))}")

    return ACTION_PREFIX + "&".join(parts)


def decode_action(href: str) -> Optional[Dict]:
    if not href.startswith(ACTION_PREFIX):
        return None

    query = href[len(ACTION_PREFIX) :]
    result = {}  # type: Dict

    if query:
        for part in query.split("&"):
            key, _, value = part.partition("=")
            result[urllib.parse.unquote(key)] = urllib.parse.unquote(value)

    if "action" not in result:
        return None

    return result
