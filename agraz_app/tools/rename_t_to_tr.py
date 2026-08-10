from pathlib import Path
import re

root = Path("lib")
for p in root.rglob("*.dart"):
    text = p.read_text(encoding="utf-8")
    if "l10n/app_l10n" not in text and p.name != "app_l10n.dart":
        continue
    orig = text
    # t('...') / t("...") -> tr('...') / tr("...")
    text = re.sub(r"(?<![\w.])t\(\s*'", "tr('", text)
    text = re.sub(r'(?<![\w.])t\(\s*"', 'tr("', text)
    text = text.replace("const AppCard(", "AppCard(")
    text = text.replace("const EmptyState(", "EmptyState(")
    text = text.replace("const SectionTitle(", "SectionTitle(")
    if text != orig:
        p.write_text(text, encoding="utf-8")
        print("updated", p)
