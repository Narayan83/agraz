import ast
import re
from pathlib import Path

kn_text = Path("lib/l10n/translations_kn.dart").read_text(encoding="utf-8")
KEYS = []
for m in re.finditer(r"""^\s*(['"])((?:\\.|(?!\1).)*)\1\s*:""", kn_text, flags=re.M):
    raw = m.group(1) + m.group(2) + m.group(1)
    try:
        KEYS.append(ast.literal_eval(raw))
    except Exception as e:
        print("bad key", raw, e)

print("count", len(KEYS))
print("short", [repr(k) for k in KEYS if len(k) <= 2])
print("has paren", [repr(k) for k in KEYS if ")" in k or "(" in k])

sample = """
              DataColumn(label: Text('Name')),
              DataColumn(label: Text('D/H'), numeric: true),
              title: const Text('Cooling period'),
              child: const Text('OK'),
"""

text = sample
for key in sorted(KEYS, key=len, reverse=True):
    single = key.replace("\\", "\\\\").replace("'", "\\'")
    double = key.replace("\\", "\\\\").replace('"', '\\"')
    for lit in (f"'{single}'", f'"{double}"'):
        pattern = rf"(?<![\w])(?:const\s+)?Text\(\s*{re.escape(lit)}\s*\)"
        text2 = re.sub(pattern, f"Text(t({lit}))", text)
        for prop in ("title", "subtitle", "text", "labelText", "hintText", "helperText", "tooltip", "semanticLabel", "headerValue"):
            pattern = rf"({prop}\s*:\s*){re.escape(lit)}"
            text2 = re.sub(pattern, rf"\1t({lit})", text2)
        if text2 != text:
            # show if suspicious
            if "))," in text2 and "))," not in text.replace("Text(", "X("):
                pass
            text = text2

print("=== result ===")
print(text)
print("suspicious Text') )), count", len(re.findall(r"Text\('[^']*'\)\),", text)))
