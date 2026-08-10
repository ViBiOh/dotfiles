import unittest

try:
    from .urls import parse_pr_url
except ImportError:
    from urls import parse_pr_url


class ParsePrUrlTest(unittest.TestCase):
    def test_cases(self):
        cases = {
            "plain": (
                "https://github.com/o/r/pull/42",
                {"owner": "o", "repo": "r", "number": 42},
            ),
            "files_tab": (
                "https://github.com/o/r/pull/42/files",
                {"owner": "o", "repo": "r", "number": 42},
            ),
            "commits_tab": (
                "https://github.com/o/r/pull/42/commits",
                {"owner": "o", "repo": "r", "number": 42},
            ),
            "trailing_slash": (
                "https://github.com/o/r/pull/42/",
                {"owner": "o", "repo": "r", "number": 42},
            ),
            "fragment": (
                "https://github.com/o/r/pull/42#discussion_r1",
                {"owner": "o", "repo": "r", "number": 42},
            ),
            "files_fragment": (
                "https://github.com/o/r/pull/42/files#diff-abc123",
                {"owner": "o", "repo": "r", "number": 42},
            ),
            "query_string": (
                "https://github.com/o/r/pull/42?w=1",
                {"owner": "o", "repo": "r", "number": 42},
            ),
            "query_and_fragment": (
                "https://github.com/o/r/pull/42/files?w=1#diff-abc",
                {"owner": "o", "repo": "r", "number": 42},
            ),
            "http_scheme": (
                "http://github.com/o/r/pull/42",
                {"owner": "o", "repo": "r", "number": 42},
            ),
            "surrounding_whitespace": (
                "  https://github.com/o/r/pull/42  ",
                {"owner": "o", "repo": "r", "number": 42},
            ),
            "large_number": (
                "https://github.com/o/r/pull/1234567",
                {"owner": "o", "repo": "r", "number": 1234567},
            ),
            "dotted_repo": (
                "https://github.com/my-org/my.repo/pull/9",
                {
                    "owner": "my-org",
                    "repo": "my.repo",
                    "number": 9,
                },
            ),
            "enterprise": (
                "https://github.mycorp.com/o/r/pull/7",
                {"owner": "o", "repo": "r", "number": 7},
            ),
            "enterprise_deep_host": (
                "https://git.internal.example.co.uk/team/proj/pull/3/files",
                {
                    "owner": "team",
                    "repo": "proj",
                    "number": 3,
                },
            ),
            "issue_rejected": ("https://github.com/o/r/issues/42", None),
            "tree_rejected": ("https://github.com/o/r/tree/main", None),
            "blob_rejected": ("https://github.com/o/r/blob/main/file.py", None),
            "non_numeric_pr": ("https://github.com/o/r/pull/abc", None),
            "empty_pr_number": ("https://github.com/o/r/pull/", None),
            "no_pr_number": ("https://github.com/o/r/pull", None),
            "pulls_listing": ("https://github.com/o/r/pulls", None),
            "repo_root": ("https://github.com/o/r", None),
            "missing_repo": ("https://github.com/o/pull/42", None),
            "trailing_number_in_repo": ("https://github.com/o/r/pull42", None),
            "garbage": ("not a url", None),
            "empty": ("", None),
            "none_input": (None, None),
            "ftp_scheme": ("ftp://github.com/o/r/pull/42", None),
            "bare_host": ("github.com/o/r/pull/42", None),
            "no_host": ("https:///o/r/pull/42", None),
            "negative_number": ("https://github.com/o/r/pull/-5", None),
        }

        for name, (url, expected) in cases.items():
            with self.subTest(name=name):
                self.assertEqual(parse_pr_url(url), expected)


if __name__ == "__main__":
    unittest.main()
