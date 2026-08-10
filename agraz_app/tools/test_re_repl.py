import re

lit = "'Cooling period'"
pat = rf"(?<![\w])(?:const\s+)?Text\(\s*{re.escape(lit)}\s*\)"
s = "title: const Text('Cooling period'),"
repl = f"Text(t({lit}))"
print("repl bytes:", list(repl))
print("f-string:", repr(re.sub(pat, repl, s)))
print("lambda:", repr(re.sub(pat, lambda m: f"Text(t({lit}))", s)))

# The classic bug: accidental raw/backslash
repl2 = "Text(t(" + lit + "))"
print("concat:", repr(re.sub(pat, repl2, s)))

# What if someone used rf with \t
try:
    print("rf:", repr(re.sub(pat, rf"Text(t({lit}))", s)))
except Exception as e:
    print("rf err", e)
