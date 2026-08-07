"""In-memory session state for a loaded pull request.

Holds everything the commands and the event listener need while a PR review is
active. There is exactly one live review at a time (multiple concurrent PRs are
deferred). Nothing here imports ``sublime`` so it stays trivially importable."""


class Session:
    def __init__(self):
        self.reset()

    def reset(self):
        self.active = False
        self.root = None
        self.pr = None
        self.review = None
        self.files = []
        self.files_by_path = {}
        self.threads_by_path = {}
        self.line_maps = {}
        self.base_blob_cache = {}
        self.owners_by_path = {}

    def unresolved_count(self, path):
        threads = self.threads_by_path.get(path, [])

        return sum(1 for thread in threads if not thread.get("is_resolved"))

    def pending_by_path(self):
        counts = {}
        drafts = self.review.drafts() if self.review else []
        for draft in drafts:
            path = draft.get("path")
            counts[path] = counts.get(path, 0) + 1

        return counts

    def file_entries_for_panel(self):
        """changed_files entries enriched with ``unresolved`` and ``pending``
        counts, ordered alphabetically by path."""
        pending = self.pending_by_path()

        entries = []
        for entry in self.files:
            enriched = dict(entry)
            enriched["unresolved"] = self.unresolved_count(entry["path"])
            enriched["pending"] = pending.get(entry["path"], 0)
            enriched["owners"] = self.owners_by_path.get(entry["path"], "")
            entries.append(enriched)

        entries.sort(key=lambda item: item["path"])

        return entries


SESSION = Session()
