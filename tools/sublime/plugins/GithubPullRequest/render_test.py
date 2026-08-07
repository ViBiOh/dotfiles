import unittest

try:
    from . import render
except ImportError:
    import render


class EncodeDecodeTest(unittest.TestCase):
    def test_roundtrip(self):
        cases = {
            "simple_comment": (
                ("comment",),
                {"side": "LEFT", "line": 12, "path": "a/b.go"},
                {
                    "action": "comment",
                    "side": "LEFT",
                    "line": "12",
                    "path": "a/b.go",
                },
            ),
            "path_with_spaces": (
                ("comment",),
                {"path": "src/my file.go", "line": 3},
                {"action": "comment", "path": "src/my file.go", "line": "3"},
            ),
            "value_with_ampersand": (
                ("open",),
                {"url": "https://x/y?a=1&b=2"},
                {"action": "open", "url": "https://x/y?a=1&b=2"},
            ),
            "unicode_value": (
                ("reply",),
                {"id": "thrëad✎id"},
                {"action": "reply", "id": "thrëad✎id"},
            ),
            "no_params": (
                ("resolve",),
                {},
                {"action": "resolve"},
            ),
        }

        for name, (pos_args, params, expected) in cases.items():
            with self.subTest(name):
                href = render.encode_action(*pos_args, **params)
                self.assertTrue(href.startswith("subl:githubpullrequest?"))
                self.assertEqual(render.decode_action(href), expected)

    def test_encode_is_sorted_and_deterministic(self):
        first = render.encode_action("comment", path="a.go", line=1, side="RIGHT")
        second = render.encode_action("comment", side="RIGHT", line=1, path="a.go")
        self.assertEqual(first, second)
        self.assertEqual(
            first,
            "subl:githubpullrequest?action=comment&line=1&path=a.go&side=RIGHT",
        )

    def test_decode_rejects_non_githubpullrequest(self):
        cases = {
            "http": "http://github.com/foo/bar",
            "https": "https://example.com/pull/1",
            "empty": "",
            "other_scheme": "subl:somethingelse?action=x",
        }

        for name, href in cases.items():
            with self.subTest(name):
                self.assertIsNone(render.decode_action(href))


class ThreadPopupTest(unittest.TestCase):
    def _thread(self, **overrides):
        thread = {
            "id": "T1",
            "url": "https://github.com/o/r/pull/1#d1",
            "is_resolved": False,
            "is_outdated": False,
            "comments": [
                {
                    "author": "alice",
                    "created_at": "2026-07-31T10:00:00Z",
                    "body": "hello",
                }
            ],
        }
        thread.update(overrides)
        return thread

    def test_escapes_html_injection(self):
        thread = self._thread(
            comments=[
                {
                    "author": "<b>bob</b>",
                    "created_at": "now",
                    "body": "<script>alert(1)</script>",
                }
            ]
        )
        html_doc = render.thread_popup_html(thread)

        self.assertIn("&lt;script&gt;", html_doc)
        self.assertNotIn("<script>", html_doc)
        self.assertNotIn("<b>bob</b>", html_doc)
        self.assertIn("&lt;b&gt;bob", html_doc)

    def test_starts_with_style_and_has_actions(self):
        html_doc = render.thread_popup_html(self._thread())

        self.assertTrue(html_doc.startswith(render.build_style()))
        self.assertIn("alice", html_doc)
        self.assertIn(">Reply<", html_doc)
        self.assertIn(">Resolve<", html_doc)
        self.assertIn(">Open<", html_doc)
        self.assertIn("action=reply", html_doc)
        self.assertIn("action=open", html_doc)

    def test_inline_and_fenced_code(self):
        thread = self._thread(
            comments=[
                {
                    "author": "a",
                    "created_at": "t",
                    "body": "use `foo` here\n```\nblock\n```",
                }
            ]
        )
        html_doc = render.thread_popup_html(thread)

        self.assertIn("<code>foo</code>", html_doc)
        self.assertIn("<code>block</code>", html_doc)
        self.assertIn("<br>", html_doc)

    def test_suggestion_block_apply_link(self):
        thread = self._thread(
            comments=[
                {
                    "author": "a",
                    "created_at": "t",
                    "body": "try this:\n```suggestion\nreturn 42\n```",
                }
            ]
        )
        html_doc = render.thread_popup_html(thread)

        self.assertIn('class="suggestion"', html_doc)
        self.assertIn(">Apply<", html_doc)
        self.assertIn("action=apply_suggestion", html_doc)
        self.assertIn("sug=0", html_doc)
        self.assertIn("return 42", html_doc)

    def test_tags_only_when_flagged(self):
        cases = {
            "none": (False, False, False, False),
            "resolved": (True, False, True, False),
            "outdated": (False, True, False, True),
            "both": (True, True, True, True),
        }

        for name, (resolved, outdated, want_res, want_out) in cases.items():
            with self.subTest(name):
                html_doc = render.thread_popup_html(
                    self._thread(is_resolved=resolved, is_outdated=outdated)
                )

                self.assertEqual('class="tag-resolved"' in html_doc, want_res)
                self.assertEqual('class="tag-outdated"' in html_doc, want_out)

                if resolved:
                    self.assertIn(">Unresolve<", html_doc)
                    self.assertIn("action=unresolve", html_doc)
                else:
                    self.assertIn(">Resolve<", html_doc)
                    self.assertIn("action=resolve", html_doc)


class HtmlToMinihtmlTest(unittest.TestCase):
    def test_conversions(self):
        cases = {
            "paragraph_and_bold": (
                "<p>hi <strong>there</strong></p>",
                "<p>hi <strong>there</strong></p>",
            ),
            "remaps_b_and_i": (
                "<b>x</b><i>y</i>",
                "<strong>x</strong><em>y</em>",
            ),
            "link_keeps_href": (
                '<a href="https://x/y">link</a>',
                '<a href="https://x/y">link</a>',
            ),
            "drops_unknown_tag_keeps_text": (
                "<table><tr><td>cell</td></tr></table>",
                "cell",
            ),
            "strips_script_content": (
                "keep<script>alert(1)</script>end",
                "keepend",
            ),
            "image_becomes_alt": (
                '<img src="x" alt="diagram">',
                "[diagram]",
            ),
            "checkbox_task_list": (
                '<input type="checkbox" checked> done',
                "☑  done",
            ),
        }

        for name, (source, expected) in cases.items():
            with self.subTest(name):
                self.assertEqual(render.html_to_minihtml(source), expected)

    def test_pre_preserves_newlines(self):
        out = render.html_to_minihtml("<pre><code>a\nb</code></pre>")
        self.assertIn("a<br>b", out)

    def test_escapes_text_nodes(self):
        # a bare < in a text node must not become raw markup
        out = render.html_to_minihtml("<p>2 &lt; 3 &amp; 4</p>")
        self.assertIn("2 &lt; 3 &amp; 4", out)
        self.assertNotIn("<3", out)


class ThreadPopupBodyHtmlTest(unittest.TestCase):
    def _thread(self, comment):
        return {
            "id": "T1",
            "url": "u",
            "is_resolved": False,
            "is_outdated": False,
            "comments": [comment],
        }

    def test_renders_body_html_when_present(self):
        thread = self._thread(
            {
                "author": "a",
                "created_at": "t",
                "body": "**bold**",
                "body_html": "<p>rendered <strong>bold</strong></p>",
            }
        )
        html_doc = render.thread_popup_html(thread)
        self.assertIn("<strong>bold</strong>", html_doc)
        self.assertNotIn("**bold**", html_doc)

    def test_body_html_suggestion_apply_link(self):
        thread = self._thread(
            {
                "author": "a",
                "created_at": "t",
                "body": "try:\n```suggestion\nreturn 42\n```",
                "body_html": "<p>try:</p><pre>return 42</pre>",
            }
        )
        html_doc = render.thread_popup_html(thread)
        self.assertIn("action=apply_suggestion", html_doc)
        self.assertIn("sug=0", html_doc)

    def test_body_html_injection_is_sanitized(self):
        thread = self._thread(
            {
                "author": "a",
                "created_at": "t",
                "body": "x",
                "body_html": "<script>alert(1)</script><p>safe</p>",
            }
        )
        html_doc = render.thread_popup_html(thread)
        self.assertNotIn("<script>", html_doc)
        self.assertIn("safe", html_doc)


class PendingHtmlTest(unittest.TestCase):
    def test_renders_body_edit_and_discard_links(self):
        html_doc = render.pending_html([(2, {"body": "please rename"})])

        self.assertIn("pending review comment", html_doc)
        self.assertIn("please rename", html_doc)
        self.assertIn("action=discard", html_doc)
        self.assertIn("action=edit", html_doc)
        self.assertIn("uid=2", html_doc)
        self.assertIn(">Edit</a>", html_doc)

    def test_escapes_body(self):
        html_doc = render.pending_html([(0, {"body": "<script>x</script>"})])

        self.assertNotIn("<script>", html_doc)
        self.assertIn("&lt;script&gt;", html_doc)


class DraftBadgeTest(unittest.TestCase):
    def test_pluralization(self):
        cases = {
            "zero": (0, ""),
            "one": (1, "✎ 1 draft"),
            "many": (3, "✎ 3 drafts"),
        }

        for name, (count, expected) in cases.items():
            with self.subTest(name):
                self.assertEqual(render.draft_badge(count), expected)


if __name__ == "__main__":
    unittest.main()
