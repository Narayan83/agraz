"""Bisect using exact apply_l10n_safe.wrap_file replacement style (f-string)."""
import re
from pathlib import Path
import apply_l10n_safe as m

src = Path(r"C:/Users/tss/AppData/Roaming/Cursor/User/History/-159391b2/hqfB.dart")
text = m.ensure_import(src.read_text(encoding="utf-8"))


def snippet(text: str) -> str:
    i = text.find("Cooling period")
    return repr(text[i - 50 : i + 35])


print("start", snippet(text))

for idx, key in enumerate(m.SORTED_KEYS):
    prev = snippet(text)
    for lit in m.dart_escape(key):
        pattern = rf"(?<![\w])(?:const\s+)?Text\(\s*{re.escape(lit)}\s*\)"
        text = re.sub(pattern, f"Text(t({lit}))", text)
        for prop in list(m.STRING_PROPS) + ["title", "subtitle", "text"]:
            pattern = rf"({prop}\s*:\s*){re.escape(lit)}"
            text = re.sub(pattern, rf"\1t({lit})", text)
    now = snippet(text)
    if now != prev:
        print(f"#{idx} {key!r}")
        print(" ", now)

print("final", snippet(text))
