"""Find which key corrupts the Cooling period dialog line."""
import re
from pathlib import Path
import apply_l10n_safe as m

src = Path(r"C:/Users/tss/AppData/Roaming/Cursor/User/History/-159391b2/hqfB.dart")
text = m.ensure_import(src.read_text(encoding="utf-8"))

needle = "Cooling period"


def snippet(text: str) -> str:
    i = text.find(needle)
    return text[i - 50 : i + 35]


print("start:", repr(snippet(text)))

for idx, key in enumerate(m.SORTED_KEYS):
    prev_snip = snippet(text)
    for lit in m.dart_escape(key):
        pattern = rf"(?<![\w])(?:const\s+)?Text\(\s*{re.escape(lit)}\s*\)"
        # IMPORTANT: use callable repl to avoid backslash interpretation
        text = re.sub(pattern, lambda _m, lit=lit: f"Text(t({lit}))", text)
        for prop in list(m.STRING_PROPS) + ["title", "subtitle", "text"]:
            pattern = rf"({prop}\s*:\s*){re.escape(lit)}"
            text = re.sub(
                pattern,
                lambda mobj, lit=lit: f"{mobj.group(1)}t({lit})",
                text,
            )
    new_snip = snippet(text)
    if new_snip != prev_snip:
        print(f"#{idx} key={key!r}")
        print("  ", repr(new_snip))

print("final:", repr(snippet(text)))
