"""Import Pokemon Yellow JP GBC back sprites as the Gen 1 shiny set.

Bulbagarden's hashed media/upload directories differ for every image. The
Special:Redirect endpoint resolves each stable archive title instead.
Downloaded PNGs are preserved byte-for-byte; this tool only renames them to
the battle-art species slugs used by the mod.
"""

from __future__ import annotations

import argparse
import re
import time
import urllib.parse
import urllib.request
from io import BytesIO
from pathlib import Path

from PIL import Image


SOURCE = "https://archives.bulbagarden.net/wiki/Special:Redirect/file"
ENTRY = re.compile(
    r'^  ([A-Z0-9_]+) = \{\n'
    r'    front = \{ image = "assets/battle/front-animated/gen5/([^/]+)\.png"',
    re.MULTILINE,
)


def species(root: Path) -> list[tuple[str, str]]:
    source = (root / "data" / "animated_battle_sprites_gen5.lua").read_text(
        encoding="utf-8"
    )
    roster = ENTRY.findall(source)
    if len(roster) != 151:
        raise ValueError(f"expected 151 Kanto species definitions, got {len(roster)}")
    return roster


def download(url: str, retries: int = 4) -> bytes:
    request = urllib.request.Request(
        url,
        headers={"User-Agent": "DramaticShapeVoxelMod battle-art importer"},
    )
    for attempt in range(retries):
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                return response.read()
        except Exception:
            if attempt + 1 == retries:
                raise
            time.sleep(1.5 * (attempt + 1))
    raise AssertionError("unreachable")


def validate_png(raw: bytes, number: int) -> tuple[int, int, str]:
    if not raw.startswith(b"\x89PNG\r\n\x1a\n"):
        raise ValueError(f"#{number:03d} response is not a PNG")
    with Image.open(BytesIO(raw)) as image:
        image.verify()
    with Image.open(BytesIO(raw)) as image:
        return image.width, image.height, image.mode


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--base-url", default=SOURCE)
    parser.add_argument("--force", action="store_true",
                        help="redownload files which already validate as PNGs")
    args = parser.parse_args()

    root = args.root.resolve()
    destination = root / "assets/battle/back-static/gen1/shiny"
    destination.mkdir(parents=True, exist_ok=True)
    roster = species(root)
    seen: set[str] = set()

    for number, (_, slug) in enumerate(roster, 1):
        archive_name = f"Spr b 1y {number:03d} GBC JP.png"
        url = f"{args.base_url.rstrip('/')}/{urllib.parse.quote(archive_name)}"
        output = destination / f"{slug}.png"
        raw = output.read_bytes() if output.is_file() and not args.force else download(url)
        width, height, mode = validate_png(raw, number)
        output.write_bytes(raw)
        seen.add(output.name)
        print(f"[{number:03d}/151] {slug:<12s} {width}x{height} {mode}", flush=True)

    expected = {f"{slug}.png" for _, slug in roster}
    if seen != expected or not (destination / "bulbasaur.png").is_file() \
            or not (destination / "mew.png").is_file():
        raise RuntimeError("downloaded filename set does not match Bulbasaur-Mew")
    print(f"wrote {len(seen)} unmodified PNGs to {destination}")


if __name__ == "__main__":
    main()
