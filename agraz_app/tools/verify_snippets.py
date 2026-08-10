from pathlib import Path
import re

login = Path("lib/login.dart").read_text(encoding="utf-8")
i = login.find("Cooling period")
print("LOGIN SNIPPET:")
print(login[i - 50 : i + 80])
print()
labour = Path("lib/labour.dart").read_text(encoding="utf-8")
for m in re.finditer(r"DataColumn\([^\n]+", labour):
    print(m.group(0))
    if m.start() > labour.find("columns:"):
        if labour[m.start():].count("DataColumn") > 8:
            break
