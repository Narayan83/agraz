from pathlib import Path
import apply_l10n_safe as m

src = Path(r"C:/Users/tss/AppData/Roaming/Cursor/User/History/-159391b2/hqfB.dart")
text = src.read_text(encoding="utf-8")
updated = m.wrap_file(text)
# show all occurrences
idx = 0
while True:
    i = updated.find("Cooling period", idx)
    if i < 0:
        break
    print(repr(updated[i - 40 : i + 30]))
    idx = i + 1

# count Text(t( vs broken
print("Text(t('Cooling period')) count", updated.count("Text(t('Cooling period'))"))
print("Text('Cooling period')) count", updated.count("Text('Cooling period'))"))
print("title: Text('Cooling period')), count", updated.count("title: Text('Cooling period')),"))
