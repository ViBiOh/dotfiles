import unittest

try:
    from .diff import parse_unified_diff
except ImportError:
    from diff import parse_unified_diff


SINGLE = """diff --git a/foo.txt b/foo.txt
index 1111111..2222222 100644
--- a/foo.txt
+++ b/foo.txt
@@ -1,3 +1,4 @@
 line1
 line2
+added
 line3
"""

MULTI_FILE = """diff --git a/foo.txt b/foo.txt
index 1111111..2222222 100644
--- a/foo.txt
+++ b/foo.txt
@@ -1,2 +1,2 @@
 keep
-old
+new
diff --git a/bar.txt b/bar.txt
index 3333333..4444444 100644
--- a/bar.txt
+++ b/bar.txt
@@ -1,1 +1,2 @@
 base
+extra
"""

ADDED = """diff --git a/new.txt b/new.txt
new file mode 100644
index 0000000..1111111
--- /dev/null
+++ b/new.txt
@@ -0,0 +1,2 @@
+hello
+world
"""

DELETED = """diff --git a/old.txt b/old.txt
deleted file mode 100644
index 1111111..0000000
--- a/old.txt
+++ /dev/null
@@ -1,2 +0,0 @@
-gone1
-gone2
"""

RENAME = """diff --git a/oldname.txt b/newname.txt
similarity index 80%
rename from oldname.txt
rename to newname.txt
index 1111111..2222222 100644
--- a/oldname.txt
+++ b/newname.txt
@@ -1,2 +1,2 @@
 keep
-old line
+new line
"""

BINARY = """diff --git a/img.png b/img.png
index 1111111..2222222 100644
Binary files a/img.png and b/img.png differ
"""

MULTI_HUNK = """diff --git a/multi.txt b/multi.txt
index 1111111..2222222 100644
--- a/multi.txt
+++ b/multi.txt
@@ -1,3 +1,3 @@
 a
-b
+B
 c
@@ -10,3 +10,4 @@
 j
+K
 k
 l
"""

NO_NEWLINE = """diff --git a/eof.txt b/eof.txt
index 1111111..2222222 100644
--- a/eof.txt
+++ b/eof.txt
@@ -1,2 +1,2 @@
 first
-second
\\ No newline at end of file
+second changed
\\ No newline at end of file
"""

SINGLE_COUNT = """diff --git a/s.txt b/s.txt
index 1111111..2222222 100644
--- a/s.txt
+++ b/s.txt
@@ -5 +5 @@
-x
+y
"""


# Each case value:
#   text:      raw diff input
#   num_files: expected number of FileDiff results
#   files:     per-file expectations. Each entry is a dict of FileDiff scalar
#              fields to assert plus "lines": a list of
#              (hunk_idx, line_idx, origin, old_lineno, new_lineno, position, content)
cases = {
    "single_file_single_hunk": {
        "text": SINGLE,
        "num_files": 1,
        "files": [
            {
                "path": "foo.txt",
                "old_path": "foo.txt",
                "new_path": "foo.txt",
                "is_new": False,
                "is_deleted": False,
                "is_rename": False,
                "is_binary": False,
                "additions": 1,
                "deletions": 0,
                "num_hunks": 1,
                "lines": [
                    (0, 0, " ", 1, 1, 1, "line1"),
                    (0, 1, " ", 2, 2, 2, "line2"),
                    (0, 2, "+", None, 3, 3, "added"),
                    (0, 3, " ", 3, 4, 4, "line3"),
                ],
            }
        ],
    },
    "multi_file": {
        "text": MULTI_FILE,
        "num_files": 2,
        "files": [
            {
                "path": "foo.txt",
                "additions": 1,
                "deletions": 1,
                "num_hunks": 1,
                "lines": [
                    (0, 1, "-", 2, None, 2, "old"),
                    (0, 2, "+", None, 2, 3, "new"),
                ],
            },
            {
                "path": "bar.txt",
                "additions": 1,
                "deletions": 0,
                "num_hunks": 1,
                "lines": [
                    (0, 0, " ", 1, 1, 1, "base"),
                    (0, 1, "+", None, 2, 2, "extra"),
                ],
            },
        ],
    },
    "added_file": {
        "text": ADDED,
        "num_files": 1,
        "files": [
            {
                "path": "new.txt",
                "old_path": None,
                "new_path": "new.txt",
                "is_new": True,
                "is_deleted": False,
                "additions": 2,
                "deletions": 0,
                "num_hunks": 1,
                "lines": [
                    (0, 0, "+", None, 1, 1, "hello"),
                    (0, 1, "+", None, 2, 2, "world"),
                ],
            }
        ],
    },
    "deleted_file": {
        "text": DELETED,
        "num_files": 1,
        "files": [
            {
                "path": "old.txt",
                "old_path": "old.txt",
                "new_path": None,
                "is_new": False,
                "is_deleted": True,
                "additions": 0,
                "deletions": 2,
                "num_hunks": 1,
                "lines": [
                    (0, 0, "-", 1, None, 1, "gone1"),
                    (0, 1, "-", 2, None, 2, "gone2"),
                ],
            }
        ],
    },
    "rename_with_content_change": {
        "text": RENAME,
        "num_files": 1,
        "files": [
            {
                "path": "newname.txt",
                "old_path": "oldname.txt",
                "new_path": "newname.txt",
                "is_rename": True,
                "additions": 1,
                "deletions": 1,
                "num_hunks": 1,
                "lines": [
                    (0, 0, " ", 1, 1, 1, "keep"),
                    (0, 1, "-", 2, None, 2, "old line"),
                    (0, 2, "+", None, 2, 3, "new line"),
                ],
            }
        ],
    },
    "binary": {
        "text": BINARY,
        "num_files": 1,
        "files": [
            {
                "path": "img.png",
                "is_binary": True,
                "additions": 0,
                "deletions": 0,
                "num_hunks": 0,
                "lines": [],
            }
        ],
    },
    "multiple_hunks": {
        "text": MULTI_HUNK,
        "num_files": 1,
        "files": [
            {
                "path": "multi.txt",
                "additions": 2,
                "deletions": 1,
                "num_hunks": 2,
                "lines": [
                    # first hunk
                    (0, 0, " ", 1, 1, 1, "a"),
                    (0, 1, "-", 2, None, 2, "b"),
                    (0, 2, "+", None, 2, 3, "B"),
                    (0, 3, " ", 3, 3, 4, "c"),
                    # second hunk: position continues past the counted @@ header (pos 5)
                    (1, 0, " ", 10, 10, 6, "j"),
                    (1, 1, "+", None, 11, 7, "K"),
                    (1, 2, " ", 11, 12, 8, "k"),
                    (1, 3, " ", 12, 13, 9, "l"),
                ],
            }
        ],
    },
    "no_newline_at_eof": {
        "text": NO_NEWLINE,
        "num_files": 1,
        "files": [
            {
                "path": "eof.txt",
                "additions": 1,
                "deletions": 1,
                "num_hunks": 1,
                "num_lines": [3],
                "lines": [
                    (0, 0, " ", 1, 1, 1, "first"),
                    (0, 1, "-", 2, None, 2, "second"),
                    (0, 2, "+", None, 2, 3, "second changed"),
                ],
            }
        ],
    },
    "single_line_count_hunk": {
        "text": SINGLE_COUNT,
        "num_files": 1,
        "files": [
            {
                "path": "s.txt",
                "additions": 1,
                "deletions": 1,
                "num_hunks": 1,
                "lines": [
                    (0, 0, "-", 5, None, 1, "x"),
                    (0, 1, "+", None, 5, 2, "y"),
                ],
            }
        ],
    },
    "empty_input": {
        "text": "",
        "num_files": 0,
        "files": [],
    },
}


class ParseUnifiedDiffTest(unittest.TestCase):
    def test_parse_unified_diff(self):
        for name, case in cases.items():
            with self.subTest(name=name):
                result = parse_unified_diff(case["text"])

                self.assertEqual(len(result), case["num_files"])

                for file_idx, expected in enumerate(case["files"]):
                    file_diff = result[file_idx]

                    for key, value in expected.items():
                        if key in ("lines", "num_hunks", "num_lines"):
                            continue
                        self.assertEqual(
                            getattr(file_diff, key),
                            value,
                            "{}: file[{}].{}".format(name, file_idx, key),
                        )

                    if "num_hunks" in expected:
                        self.assertEqual(
                            len(file_diff.hunks),
                            expected["num_hunks"],
                            "{}: file[{}] hunk count".format(name, file_idx),
                        )

                    if "num_lines" in expected:
                        for hunk_idx, count in enumerate(expected["num_lines"]):
                            self.assertEqual(
                                len(file_diff.hunks[hunk_idx].lines),
                                count,
                                "{}: file[{}].hunk[{}] line count".format(
                                    name, file_idx, hunk_idx
                                ),
                            )

                    for check in expected["lines"]:
                        hunk_idx, line_idx, origin, old, new, position, content = check
                        line = file_diff.hunks[hunk_idx].lines[line_idx]

                        label = "{}: file[{}].hunk[{}].line[{}]".format(
                            name, file_idx, hunk_idx, line_idx
                        )
                        self.assertEqual(line.origin, origin, label + " origin")
                        self.assertEqual(line.old_lineno, old, label + " old_lineno")
                        self.assertEqual(line.new_lineno, new, label + " new_lineno")
                        self.assertEqual(line.position, position, label + " position")
                        self.assertEqual(line.content, content, label + " content")


if __name__ == "__main__":
    unittest.main()
