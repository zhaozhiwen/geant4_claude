#!/usr/bin/env python3
"""Embed external images in an HTML file as base64 data URIs.

Reads <input.html>, finds each `<img src="X">` where X is not already a
data URI, encodes the file at X (resolved relative to the HTML file's
own directory) as base64, and writes a sibling `<stem>_portable.html`
with the embeds in place. The original path is preserved as
`data-source="X"` for traceability.

Mimetype is auto-detected from the file extension (PNG / JPG / GIF / SVG
/ WEBP / etc.); unknown types fall back to image/png.

Idempotent — re-running on an already-embedded file is a no-op (the
regex's negative-lookahead skips `src="data:..."` tags).

Usage:
    python3 embed_html.py <input.html> [--output <out.html>]
"""
import argparse
import base64
import mimetypes
import pathlib
import re
import sys

IMG_RE = re.compile(r'<img\s+([^>]*?)src="(?!data:)([^"]+)"', re.DOTALL)
COMMENT_RE = re.compile(r'<!--.*?-->', re.DOTALL)


def datauri(path):
    mime, _ = mimetypes.guess_type(str(path))
    if mime is None or not mime.startswith("image/"):
        mime = "image/png"
    return f"data:{mime};base64," + base64.b64encode(path.read_bytes()).decode("ascii")


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("input", help="path to source HTML file")
    ap.add_argument("--output", help="output path (default: <stem>_portable.html alongside input)")
    args = ap.parse_args()

    src = pathlib.Path(args.input).resolve()
    if not src.exists():
        sys.exit(f"missing: {src}")
    anchor = src.parent
    dst = pathlib.Path(args.output).resolve() if args.output else src.with_name(f"{src.stem}_portable{src.suffix}")

    html = src.read_text()
    refs = []

    def replace(m):
        prefix = re.sub(r'data-source="[^"]*"\s*', '', m.group(1))  # avoid duplicate attr if already tagged
        rel = m.group(2)
        img = anchor / rel
        if not img.exists():
            sys.exit(f"missing image: {img} (referenced from {src.name})")
        refs.append(rel)
        return f'<img {prefix}src="{datauri(img)}" data-source="{rel}"'

    # Skip <img> tags that sit inside HTML comments — they're placeholders
    # the user hasn't activated yet, not real references to embed.
    parts = []
    last = 0
    for m in COMMENT_RE.finditer(html):
        parts.append(IMG_RE.sub(replace, html[last:m.start()]))
        parts.append(m.group(0))
        last = m.end()
    parts.append(IMG_RE.sub(replace, html[last:]))
    out_html = ''.join(parts)
    if not refs:
        sys.exit("no <img src=...> tags with external refs found in input")

    dst.write_text(out_html)
    print(f"read  {src}: {src.stat().st_size / 1024:.1f} KB")
    print(f"wrote {dst}: {dst.stat().st_size / 1024:.1f} KB ({len(refs)} image(s) embedded)")
    for r in refs:
        kb = (anchor / r).stat().st_size / 1024
        print(f"  {r}  ({kb:.1f} KB)")


if __name__ == "__main__":
    main()
