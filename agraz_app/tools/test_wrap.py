import re

s = """builder: (ctx) => AlertDialog(
                    title: const Text('Cooling period'),
                    content: const Text(
                      'You are in cooling period. Please wait for approval. '
                      'An admin will verify your account before you can sign in.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('OK'),
                      ),
                    ],
                  ),"""

cols = """
            columns: const [
              DataColumn(label: Text('Name')),
              DataColumn(label: Text('Shift')),
              DataColumn(label: Text('D/H'), numeric: true),
              DataColumn(label: Text('Gender')),
              DataColumn(label: Text('Rate'), numeric: true),
              DataColumn(label: Text('Category')),
              DataColumn(label: Text('')),
            ],
"""


def wrap(text: str, keys: list[str]) -> str:
    for key in keys:
        single = key.replace("\\", "\\\\").replace("'", "\\'")
        lit = f"'{single}'"
        pattern = rf"(?<![\w])(?:const\s+)?Text\(\s*{re.escape(lit)}\s*\)"
        text = re.sub(pattern, f"Text(t({lit}))", text)
        for prop in ("title", "subtitle", "text", "labelText"):
            pattern = rf"({prop}\s*:\s*){re.escape(lit)}"
            text = re.sub(pattern, rf"\1t({lit})", text)
    return text


print("=== dialog ===")
print(wrap(s, ["Cooling period", "OK"]))
print("=== cols ===")
print(wrap(cols, ["Name", "Shift", "D/H", "Gender", "Rate", "Category", ""]))
