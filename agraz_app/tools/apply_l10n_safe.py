"""Wrap only Text('catalog key') and string-only InputDecoration fields."""
from __future__ import annotations

import ast
import re
from pathlib import Path

ROOT = Path(r"d:/fullstack/others/app_agraz/agraz_app/lib")
KN = ROOT / "l10n/translations_kn.dart"

kn_text = KN.read_text(encoding="utf-8")
KEYS: set[str] = set()
for m in re.finditer(r"""^\s*(['"])((?:\\.|(?!\1).)*)\1\s*:""", kn_text, flags=re.M):
    raw = m.group(1) + m.group(2) + m.group(1)
    try:
        KEYS.add(ast.literal_eval(raw))
    except Exception:
        continue

SORTED_KEYS = sorted(KEYS, key=len, reverse=True)

FILES = [
    "login.dart",
    "registration.dart",
    "reset_password_page.dart",
    "profile_page.dart",
    "about_page.dart",
    "terms.dart",
    "mainpage.dart",
    "income_expense.dart",
    "income_expense_view.dart",
    "income_expense_report.dart",
    "address_page.dart",
    "labour.dart",
    "labour_summary.dart",
    "marke_report.dart",
    "buy_and_sell.dart",
    "services.dart",
    "service_register.dart",
    "government_facilities.dart",
    "farmer_education.dart",
    "category_create.dart",
    "subcategory_create.dart",
    "welcome_screen.dart",
    "help_page.dart",
]

# String-only named params (never Widgets)
STRING_PROPS = (
    "labelText",
    "hintText",
    "helperText",
    "tooltip",
    "semanticLabel",
    "headerValue",
)


def dart_escape(s: str) -> list[str]:
    single = s.replace("\\", "\\\\").replace("'", "\\'")
    double = s.replace("\\", "\\\\").replace('"', '\\"')
    return [f"'{single}'", f'"{double}"']


def ensure_import(text: str) -> str:
    if "l10n/app_l10n.dart" in text:
        return text
    lines = text.splitlines(True)
    insert_at = 0
    for i, line in enumerate(lines):
        if line.startswith("import "):
            insert_at = i + 1
    lines.insert(insert_at, "import 'l10n/app_l10n.dart';\n")
    return "".join(lines)


def wrap_file(text: str) -> str:
    text = ensure_import(text)
    for key in SORTED_KEYS:
        for lit in dart_escape(key):
            # Whole Text('key') / const Text('key') only
            pattern = rf"(?<![\w])(?:const\s+)?Text\(\s*{re.escape(lit)}\s*\)"
            text = re.sub(pattern, lambda _m, lit=lit: f"Text(t({lit}))", text)

            for prop in STRING_PROPS + ("title", "subtitle", "text"):
                pattern = rf"({prop}\s*:\s*){re.escape(lit)}"
                text = re.sub(
                    pattern,
                    lambda mobj, lit=lit: f"{mobj.group(1)}t({lit})",
                    text,
                )

    # Do NOT collapse "t(t(" — that substring appears inside "Text(t("!
    return text


def main() -> None:
    print(f"Keys: {len(SORTED_KEYS)}")
    for name in FILES:
        path = ROOT / name
        if not path.exists():
            print("MISSING", name)
            continue
        original = path.read_text(encoding="utf-8")
        # Strip any prior partial l10n import duplication
        updated = wrap_file(original)
        if updated != original:
            path.write_text(updated, encoding="utf-8")
            print("UPDATED", name)
        else:
            print("UNCHANGED", name)


if __name__ == "__main__":
    main()
