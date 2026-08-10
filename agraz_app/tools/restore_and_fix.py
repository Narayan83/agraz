"""Restore files from Cursor history and fix Text('...')), corruption."""
from __future__ import annotations

import re
from pathlib import Path

LIB = Path(r"d:/fullstack/others/app_agraz/agraz_app/lib")
HIST = Path(r"C:/Users/tss/AppData/Roaming/Cursor/User/History")

PAIRS = {
    "income_expense.dart": HIST / "-374669ff/XWEQ.dart",
    "labour.dart": HIST / "746b5f44/mn9S.dart",
    "login.dart": HIST / "-159391b2/hqfB.dart",
    "income_expense_view.dart": HIST / "-7e6a712b/VrsB.dart",
    "income_expense_report.dart": HIST / "-6cc4019a/S9NR.dart",
    "labour_summary.dart": HIST / "45e0723d/scMo.dart",
}


def fix_extra_parens(text: str) -> str:
    # Remove l10n imports so we re-add cleanly later
    lines = [ln for ln in text.splitlines(True) if "l10n/app_l10n" not in ln]
    text = "".join(lines)

    # Text('foo')),  or Text("foo")),  -> Text('foo'),
    text = re.sub(
        r"Text\((['\"])((?:\\.|[^\\])*?)\1\)\s*\),",
        r"Text(\1\2\1),",
        text,
    )
    # Text(t('foo'))),
    text = re.sub(
        r"Text\(t\((['\"])((?:\\.|[^\\])*?)\1\)\)\s*\),",
        r"Text(t(\1\2\1)),",
        text,
    )
    return text


def main() -> None:
    for name, src in PAIRS.items():
        raw = src.read_text(encoding="utf-8")
        fixed = fix_extra_parens(raw)
        bad = len(re.findall(r"Text\([^\n]{0,80}\)\),", fixed))
        (LIB / name).write_text(fixed, encoding="utf-8")
        print(f"{name}: {len(fixed)} chars, remaining suspicious={bad}")


if __name__ == "__main__":
    main()
