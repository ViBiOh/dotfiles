"""Window layout arithmetic for the comment compose split.

Sublime layouts are plain dicts of `cols` / `rows` (0.0 to 1.0 fractions) and `cells`
(``[col_start, row_start, col_end, row_end]`` indices into them). Kept separate and
free of ``sublime`` so the arithmetic is unit-testable."""

from typing import Dict


def split_below_layout(layout: Dict, fraction: float = 0.7) -> Dict:
    """Add a full-width group below `layout`, shrinking the existing groups into the
    top `fraction`. Works for any starting layout (single group or many columns)."""
    rows = layout["rows"]
    cols = layout["cols"]

    new_rows = [row * fraction for row in rows] + [1.0]
    bottom = [0, len(rows) - 1, len(cols) - 1, len(new_rows) - 1]

    return {
        "cols": list(cols),
        "rows": new_rows,
        "cells": [list(cell) for cell in layout["cells"]] + [bottom],
    }
