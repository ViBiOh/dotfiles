import unittest

try:
    from .layout import split_below_layout
except ImportError:
    from layout import split_below_layout


_SINGLE = {"cols": [0.0, 1.0], "rows": [0.0, 1.0], "cells": [[0, 0, 1, 1]]}
_TWO_COLUMNS = {
    "cols": [0.0, 0.5, 1.0],
    "rows": [0.0, 1.0],
    "cells": [[0, 0, 1, 1], [1, 0, 2, 1]],
}
_TWO_ROWS = {
    "cols": [0.0, 1.0],
    "rows": [0.0, 0.5, 1.0],
    "cells": [[0, 0, 1, 1], [0, 1, 1, 2]],
}


class SplitBelowLayoutTest(unittest.TestCase):
    def test_shapes(self):
        cases = {
            "single_group": (
                _SINGLE,
                {
                    "cols": [0.0, 1.0],
                    "rows": [0.0, 0.7, 1.0],
                    "cells": [[0, 0, 1, 1], [0, 1, 1, 2]],
                },
            ),
            "two_columns_span_full_width": (
                _TWO_COLUMNS,
                {
                    "cols": [0.0, 0.5, 1.0],
                    "rows": [0.0, 0.7, 1.0],
                    "cells": [[0, 0, 1, 1], [1, 0, 2, 1], [0, 1, 2, 2]],
                },
            ),
            "two_rows_scale_into_the_top": (
                _TWO_ROWS,
                {
                    "cols": [0.0, 1.0],
                    "rows": [0.0, 0.35, 0.7, 1.0],
                    "cells": [[0, 0, 1, 1], [0, 1, 1, 2], [0, 2, 1, 3]],
                },
            ),
        }

        for name, (layout, expected) in cases.items():
            with self.subTest(name):
                self.assertEqual(split_below_layout(layout), expected)

    def test_rows_stay_sorted_and_bounded(self):
        for name, layout in {
            "single": _SINGLE,
            "columns": _TWO_COLUMNS,
            "rows": _TWO_ROWS,
        }.items():
            with self.subTest(name):
                rows = split_below_layout(layout)["rows"]

                self.assertEqual(rows, sorted(rows))
                self.assertEqual(rows[0], 0.0)
                self.assertEqual(rows[-1], 1.0)

    def test_does_not_mutate_the_input(self):
        layout = {"cols": [0.0, 1.0], "rows": [0.0, 1.0], "cells": [[0, 0, 1, 1]]}
        before = {
            "cols": list(layout["cols"]),
            "rows": list(layout["rows"]),
            "cells": [list(cell) for cell in layout["cells"]],
        }

        split_below_layout(layout)

        self.assertEqual(layout, before)

    def test_fraction_controls_the_split(self):
        rows = split_below_layout(_SINGLE, fraction=0.5)["rows"]

        self.assertEqual(rows, [0.0, 0.5, 1.0])


if __name__ == "__main__":
    unittest.main()
