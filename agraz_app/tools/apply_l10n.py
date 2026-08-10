"""Wrap common Flutter UI string literals with t() for AgRaz l10n."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(r"d:/fullstack/others/app_agraz/agraz_app/lib")
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
]

# Named args / constructors that take user-facing strings
ARG_KEYS = (
    "title",
    "labelText",
    "hintText",
    "helperText",
    "errorText",
    "subtitle",
    "tooltip",
    "semanticLabel",
    "label",
    "message",
    "content",
    "headerValue",
)

SKIP_IF_CONTAINS = (
    "assets/",
    "http://",
    "https://",
    "api/",
    "package:",
    "${",
    "$",
    "\\n",  # keep multi-line careful — still wrap simple ones
)


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


def should_skip(s: str) -> bool:
    if not s.strip():
        return True
    if len(s) == 1:
        return True
    # mostly punctuation / numbers
    if re.fullmatch(r"[\d\s\W]+", s):
        return True
    if any(x in s for x in ("assets/", "http://", "https://", "package:", "api/")):
        return True
    # interpolations — skip automatic wrap
    if "$" in s:
        return True
    return False


def wrap_string_literal(match: re.Match[str]) -> str:
    quote = match.group(1)
    body = match.group(2)
    if should_skip(body):
        return match.group(0)
    # already wrapped
    full = match.group(0)
    return f"t({full})"


STR = r"""(?:'(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*")"""


def lit_body(lit: str) -> str | None:
    inner = re.match(r"""(['"])(.*)\1$""", lit, re.DOTALL)
    if not inner:
        return None
    return inner.group(2)


def process(text: str) -> str:
    text = ensure_import(text)

    def repl_text(m: re.Match[str]) -> str:
        lit = m.group(2)
        body = lit_body(lit)
        if body is None or should_skip(body):
            return m.group(0)
        return f"Text(t({lit})"

    text = re.sub(rf"""(const\s+)?Text\(\s*({STR})""", repl_text, text)

    for key in ARG_KEYS:
        pattern = rf"""({key}\s*:\s*)(const\s+)?({STR})"""

        def repl(m: re.Match[str]) -> str:
            lit = m.group(3)
            body = lit_body(lit)
            if body is None or should_skip(body):
                return m.group(0)
            return f"{m.group(1)}t({lit})"

        text = re.sub(pattern, repl, text)

    def repl_return(m: re.Match[str]) -> str:
        lit = m.group(2)
        body = lit_body(lit)
        if body is None or should_skip(body):
            return m.group(0)
        return f"{m.group(1)}t({lit}){m.group(3)}"

    text = re.sub(rf"""(return\s+)({STR})(\s*;)""", repl_return, text)

    while "t(t(" in text:
        text = text.replace("t(t(", "t(")

    text = text.replace("const Text(t(", "Text(t(")
    text = text.replace("const t(", "t(")
    return text


def main() -> None:
    for name in FILES:
        path = ROOT / name
        if not path.exists():
            print("MISSING", name)
            continue
        original = path.read_text(encoding="utf-8")
        updated = process(original)
        if updated != original:
            path.write_text(updated, encoding="utf-8")
            print("UPDATED", name)
        else:
            print("UNCHANGED", name)


if __name__ == "__main__":
    main()
