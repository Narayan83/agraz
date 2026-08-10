"""Debug wrap on login.dart only."""
from pathlib import Path
import apply_l10n_safe as m

src = Path(r"C:/Users/tss/AppData/Roaming/Cursor/User/History/-159391b2/hqfB.dart")
text = src.read_text(encoding="utf-8")
print("BEFORE:", repr(text[text.find("Cooling") - 30 : text.find("Cooling") + 20]))
updated = m.wrap_file(text)
print("AFTER:", repr(updated[updated.find("Cooling") - 40 : updated.find("Cooling") + 30]))
# Also check OK button
i = updated.find("child: Text")
print("OK area:", repr(updated[updated.find("child: const Text('OK')") if "child: const Text('OK')" in updated else updated.find("child: Text(t('OK'))") : ][:60]))
Path("lib/login_debug.dart").write_text(updated, encoding="utf-8")
print("wrote login_debug.dart")
