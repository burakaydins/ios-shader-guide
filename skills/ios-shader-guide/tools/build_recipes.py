#!/usr/bin/env python3
"""Builds the generated reference docs from templates + the .metal sources.

Every `{{code:NAME}}` in a template is replaced with a ```metal block taken
from between `// <recipe:NAME>` and `// </recipe:NAME>` in any file under
examples/ShaderLab/*.metal. Fails loudly if a placeholder has no matching block
or a block is used by no template.

  tools/recipes.template.md          -> references/recipes.md
  tools/shadertoy.template.md        -> references/shadertoy-to-msl.md
  tools/advanced.template.md         -> references/advanced-techniques.md
  tools/performance.template.md      -> references/performance-debugging.md
"""
import re
import sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent   # the skill folder
PAIRS = [
    ("tools/recipes.template.md", "references/recipes.md"),
    ("tools/shadertoy.template.md", "references/shadertoy-to-msl.md"),
    ("tools/advanced.template.md", "references/advanced-techniques.md"),
    ("tools/performance.template.md", "references/performance-debugging.md"),
]

blocks = {}
for metal in sorted((root / "examples/ShaderLab").glob("*.metal")):
    for name, body in re.findall(r"// <recipe:(\w+)>\n(.*?)// </recipe:\1>", metal.read_text(), flags=re.S):
        if name in blocks:
            sys.exit(f"duplicate recipe block: {name}")
        blocks[name] = body

used = set()
for tpl, out in PAIRS:
    text = (root / tpl).read_text()
    wanted = re.findall(r"\{\{code:(\w+)\}\}", text)
    missing = [n for n in wanted if n not in blocks]
    if missing:
        sys.exit(f"{tpl}: missing blocks {missing}")
    used.update(wanted)
    rendered = re.sub(r"\{\{code:(\w+)\}\}",
                      lambda m: "```metal\n" + blocks[m.group(1)].rstrip() + "\n```", text)
    (root / out).write_text(rendered)
    print(f"wrote {out} ({len(wanted)} code blocks)")

unused = sorted(set(blocks) - used)
if unused:
    sys.exit(f"blocks not used in any template: {unused}")
