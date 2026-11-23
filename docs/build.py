import html
import os
import re
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOCS = os.path.join(ROOT, "docs")
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "build", "site")

PAGES = [
    ("index", os.path.join(ROOT, "README.md"), "Overview"),
    ("getting-started", os.path.join(DOCS, "getting-started.md"), "Getting started"),
    ("replication", os.path.join(DOCS, "replication.md"), "Replication"),
    ("events", os.path.join(DOCS, "events.md"), "Animation events"),
    ("tracks", os.path.join(DOCS, "tracks.md"), "Tracks and players"),
    ("clips-and-rigs", os.path.join(DOCS, "clips-and-rigs.md"), "Clips, rigs, masks"),
    ("features", os.path.join(DOCS, "features.md"), "More features"),
]

REPO = os.environ.get("PUNCHYROLL_REPO", "https://github.com/MintyWorks/PunchyRoll")
LINKS = {name: name + ".html" for name, _, _ in PAGES}
LINKS["README"] = "index.html"

KEYWORDS = {
    "and", "break", "continue", "do", "else", "elseif", "end", "export", "false", "for", "function", "if", "in",
    "local", "nil", "not", "or", "repeat", "return", "then", "true", "type", "until", "while", "const", "typeof",
}

TOKEN = re.compile(
    r"(?P<comment>--[^\n]*)"
    r"|(?P<string>\"(?:\\.|[^\"\\\n])*\"|'(?:\\.|[^'\\\n])*'|`(?:\\.|[^`\\])*`)"
    r"|(?P<number>\b\d+(?:\.\d+)?(?:e[+-]?\d+)?\b)"
    r"|(?P<word>[A-Za-z_][A-Za-z0-9_]*)"
    r"|(?P<other>.)",
    re.S,
)


def highlight(code, lang):
    if lang not in ("luau", "lua"):
        return html.escape(code)

    out = []
    for match in TOKEN.finditer(code):
        kind = match.lastgroup
        text = match.group()
        escaped = html.escape(text)
        if kind == "comment":
            out.append(f'<span class="c">{escaped}</span>')
        elif kind == "string":
            out.append(f'<span class="s">{escaped}</span>')
        elif kind == "number":
            out.append(f'<span class="n">{escaped}</span>')
        elif kind == "word":
            if text in KEYWORDS:
                out.append(f'<span class="k">{escaped}</span>')
            else:
                out.append(escaped)
        else:
            out.append(escaped)

    return "".join(out)


def slug(text):
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")


def inline(text):
    codes = []

    def stash(match):
        codes.append(match.group(1))
        return f"\x00{len(codes) - 1}\x00"

    text = re.sub(r"`([^`]+)`", stash, text)
    text = html.escape(text, quote=False)

    def link(match):
        label, target = match.group(1), match.group(2)
        if not re.match(r"^[a-z]+://", target) and not target.startswith("#"):
            base, _, anchor = target.partition("#")
            name = os.path.basename(base)
            if name.endswith(".md"):
                name = name[:-3]
            if name in LINKS:
                target = LINKS[name] + ("#" + anchor if anchor else "")
            elif name == "LICENSE":
                target = REPO + "/blob/main/LICENSE"
        return f'<a href="{target}">{label}</a>'

    text = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", link, text)
    text = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", text)
    text = re.sub(r"(?<![\w*])\*([^*\n]+)\*(?![\w*])", r"<em>\1</em>", text)

    def restore(match):
        return "<code>" + html.escape(codes[int(match.group(1))], quote=False) + "</code>"

    return re.sub(r"\x00(\d+)\x00", restore, text)


def render(markdown):
    lines = markdown.replace("\r\n", "\n").split("\n")
    out = []
    headings = []
    index = 0
    title = None

    while index < len(lines):
        line = lines[index]

        fence = re.match(r"^```(\w*)\s*$", line)
        if fence:
            lang = fence.group(1)
            block = []
            index += 1
            while index < len(lines) and not lines[index].startswith("```"):
                block.append(lines[index])
                index += 1
            index += 1
            out.append(f'<pre><code class="lang-{lang}">{highlight(chr(10).join(block), lang)}</code></pre>')
            continue

        heading = re.match(r"^(#{1,4})\s+(.*)$", line)
        if heading:
            level = len(heading.group(1))
            text = heading.group(2).strip()
            if level == 1 and title is None:
                title = text
            anchor = slug(text)
            if level in (2, 3):
                headings.append((level, text, anchor))
            out.append(f'<h{level} id="{anchor}">{inline(text)}</h{level}>')
            index += 1
            continue

        if line.startswith("|") and index + 1 < len(lines) and re.match(r"^\|[\s:|-]+\|\s*$", lines[index + 1]):
            header = [cell.strip() for cell in line.strip().strip("|").split("|")]
            index += 2
            rows = []
            while index < len(lines) and lines[index].startswith("|"):
                rows.append([cell.strip() for cell in lines[index].strip().strip("|").split("|")])
                index += 1
            table = ["<div class=\"table\"><table><thead><tr>"]
            table += [f"<th>{inline(cell)}</th>" for cell in header]
            table.append("</tr></thead><tbody>")
            for row in rows:
                table.append("<tr>" + "".join(f"<td>{inline(cell)}</td>" for cell in row) + "</tr>")
            table.append("</tbody></table></div>")
            out.append("".join(table))
            continue

        if re.match(r"^[-*]\s+", line) or re.match(r"^\d+\.\s+", line):
            ordered = bool(re.match(r"^\d+\.\s+", line))
            items = []
            pattern = r"^\d+\.\s+" if ordered else r"^[-*]\s+"
            while index < len(lines) and re.match(pattern, lines[index]):
                item = re.sub(pattern, "", lines[index])
                index += 1
                while index < len(lines) and lines[index].startswith("  ") and not re.match(pattern, lines[index].strip()):
                    item += " " + lines[index].strip()
                    index += 1
                items.append(item)
            tag = "ol" if ordered else "ul"
            out.append(f"<{tag}>" + "".join(f"<li>{inline(item)}</li>" for item in items) + f"</{tag}>")
            continue

        if not line.strip():
            index += 1
            continue

        paragraph = [line]
        index += 1
        while index < len(lines) and lines[index].strip() and not re.match(r"^(#{1,4}\s|```|\||[-*]\s|\d+\.\s)", lines[index]):
            paragraph.append(lines[index])
            index += 1
        out.append(f"<p>{inline(' '.join(paragraph))}</p>")

    return "\n".join(out), title, headings


TEMPLATE = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title} | PunchyRoll</title>
<meta name="description" content="PunchyRoll, an animation library for Roblox with named animation events and replication.">
<style>
:root {{
  --bg: #fbfaf8; --panel: #f3f1ed; --text: #22201d; --muted: #6a655e; --line: #e2ded7;
  --accent: #c2410c; --code-bg: #f0ede7; --k: #a21caf; --s: #15803d; --n: #b45309; --c: #8a847b;
}}
@media (prefers-color-scheme: dark) {{
  :root {{
    --bg: #161412; --panel: #1d1a17; --text: #ebe7e1; --muted: #a09a91; --line: #2c2823;
    --accent: #fb923c; --code-bg: #211e1a; --k: #e879f9; --s: #86efac; --n: #fbbf24; --c: #7c766d;
  }}
}}
* {{ box-sizing: border-box; }}
html {{ scroll-behavior: smooth; }}
body {{ margin: 0; background: var(--bg); color: var(--text); font: 16px/1.65 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; }}
a {{ color: var(--accent); text-decoration: none; }}
a:hover {{ text-decoration: underline; }}
.layout {{ display: grid; grid-template-columns: 260px minmax(0, 1fr); min-height: 100vh; }}
nav.side {{ min-width: 0; position: sticky; top: 0; height: 100vh; overflow-y: auto; padding: 28px 20px; background: var(--panel); border-right: 1px solid var(--line); }}
nav.side .brand {{ display: block; font-weight: 700; font-size: 1.25rem; color: var(--text); margin-bottom: 4px; }}
nav.side .tag {{ color: var(--muted); font-size: 0.85rem; margin-bottom: 24px; }}
nav.side a.page {{ display: block; padding: 6px 10px; margin: 2px 0; border-radius: 6px; color: var(--text); }}
nav.side a.page:hover {{ background: var(--code-bg); text-decoration: none; }}
nav.side a.page.current {{ background: var(--code-bg); color: var(--accent); font-weight: 600; }}
nav.side .toc {{ margin: 2px 0 8px 12px; border-left: 1px solid var(--line); }}
nav.side .toc a {{ display: block; padding: 2px 10px; font-size: 0.88rem; color: var(--muted); }}
nav.side .toc a.l3 {{ padding-left: 22px; }}
nav.side .gh {{ display: block; margin-top: 24px; font-size: 0.9rem; color: var(--muted); }}
main {{ min-width: 0; max-width: 820px; width: 100%; padding: 48px 32px 96px; margin: 0 auto; }}
h1 {{ font-size: 2.2rem; line-height: 1.2; margin: 0 0 16px; }}
h2 {{ font-size: 1.5rem; margin: 48px 0 12px; padding-top: 8px; border-top: 1px solid var(--line); }}
h3 {{ font-size: 1.15rem; margin: 32px 0 8px; }}
p, li {{ color: var(--text); }}
li {{ margin: 4px 0; }}
code {{ font: 0.88em ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; background: var(--code-bg); padding: 0.12em 0.35em; border-radius: 4px; }}
pre {{ background: var(--code-bg); border: 1px solid var(--line); border-radius: 8px; padding: 14px 16px; overflow-x: auto; line-height: 1.5; }}
pre code {{ background: none; padding: 0; font-size: 0.86rem; tab-size: 4; }}
.k {{ color: var(--k); }} .s {{ color: var(--s); }} .n {{ color: var(--n); }} .c {{ color: var(--c); font-style: italic; }}
.table {{ overflow-x: auto; margin: 16px 0; }}
table {{ border-collapse: collapse; width: 100%; font-size: 0.95rem; }}
th, td {{ text-align: left; padding: 8px 12px; border-bottom: 1px solid var(--line); vertical-align: top; }}
th {{ color: var(--muted); font-weight: 600; font-size: 0.85rem; text-transform: uppercase; letter-spacing: 0.03em; }}
footer {{ margin-top: 64px; padding-top: 16px; border-top: 1px solid var(--line); color: var(--muted); font-size: 0.88rem; }}
.pager {{ display: flex; justify-content: space-between; gap: 16px; margin-top: 48px; }}
.pager a {{ padding: 10px 14px; border: 1px solid var(--line); border-radius: 8px; }}
@media (max-width: 860px) {{
  .layout {{ grid-template-columns: minmax(0, 1fr); }}
  nav.side .toc {{ display: none; }}
  nav.side {{ padding: 20px; }}
  nav.side {{ position: static; height: auto; border-right: 0; border-bottom: 1px solid var(--line); }}
  main {{ padding: 28px 20px 64px; }}
}}
</style>
</head>
<body>
<div class="layout">
<nav class="side">
<a class="brand" href="index.html">PunchyRoll</a>
<div class="tag">Animation events and replication for Roblox</div>
{nav}
<a class="gh" href="{repo}">View on GitHub</a>
</nav>
<main>
{body}
<div class="pager">{pager}</div>
<footer>MIT licensed. Fork of CrunchyRoll by ffrostfall.</footer>
</main>
</div>
</body>
</html>
"""


def main():
    repo = REPO
    rendered = {}
    for name, path, label in PAGES:
        with open(path, encoding="utf-8") as handle:
            rendered[name] = render(handle.read()) + (label,)

    if os.path.isdir(OUT):
        shutil.rmtree(OUT)
    os.makedirs(OUT)

    for position, (name, _, label) in enumerate(PAGES):
        body, title, headings, _ = rendered[name]

        nav = []
        for other, _, other_label in PAGES:
            current = " current" if other == name else ""
            nav.append(f'<a class="page{current}" href="{LINKS[other]}">{html.escape(other_label)}</a>')
            if other == name and headings:
                nav.append('<div class="toc">')
                for level, text, anchor in headings:
                    nav.append(f'<a class="l{level}" href="#{anchor}">{html.escape(text)}</a>')
                nav.append("</div>")

        pager = []
        if position > 0:
            before = PAGES[position - 1]
            pager.append(f'<a href="{LINKS[before[0]]}">&larr; {html.escape(before[2])}</a>')
        else:
            pager.append("<span></span>")
        if position + 1 < len(PAGES):
            after = PAGES[position + 1]
            pager.append(f'<a href="{LINKS[after[0]]}">{html.escape(after[2])} &rarr;</a>')

        page = TEMPLATE.format(
            title=html.escape(title or label),
            nav="\n".join(nav),
            body=body,
            pager="".join(pager),
            repo=repo,
        )
        with open(os.path.join(OUT, LINKS[name]), "w", encoding="utf-8") as handle:
            handle.write(page)

    with open(os.path.join(OUT, ".nojekyll"), "w") as handle:
        handle.write("")

    print(f"Built {len(PAGES)} pages into {OUT}")


main()
