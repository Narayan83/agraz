from pathlib import Path
import re
import apply_l10n_safe as m

src = Path(r"C:/Users/tss/AppData/Roaming/Cursor/User/History/-159391b2/hqfB.dart")
text = m.ensure_import(src.read_text(encoding="utf-8"))

for key in m.SORTED_KEYS:
    for lit in m.dart_escape(key):
        pattern = rf"(?<![\w])(?:const\s+)?Text\(\s*{re.escape(lit)}\s*\)"
        text = re.sub(pattern, f"Text(t({lit}))", text)
        for prop in list(m.STRING_PROPS) + ["title", "subtitle", "text"]:
            pattern = rf"({prop}\s*:\s*){re.escape(lit)}"
            text = re.sub(pattern, rf"\1t({lit})", text)

print("before collapse:", repr(text[text.find("Cooling") - 40 : text.find("Cooling") + 30]))
print("has t(t(:", "t(t(" in text)
# show contexts of t(t(
idx = 0
while "t(t(" in text[idx:]:
    j = text.index("t(t(", idx)
    print("tt context", repr(text[j - 20 : j + 40]))
    idx = j + 1
    if idx > 500000:
        break

while "t(t(" in text:
    text = text.replace("t(t(", "t(")

print("after collapse:", repr(text[text.find("Cooling") - 40 : text.find("Cooling") + 30]))
