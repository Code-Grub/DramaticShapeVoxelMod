"""Extend normal Crystal battle art from Chikorita through Celebi."""

from __future__ import annotations

import argparse
import re
from io import BytesIO
from pathlib import Path

from PIL import Image

from import_animated_sprites import convert, lua_definition
from import_crystal_shiny_sprites import roster
from import_gen4_extended_and_shiny_sprites import fetch_candidates


SOURCE = "https://archives.bulbagarden.net/wiki/Special:Redirect/file"
FRONT_ENTRY = re.compile(
    r"^  ([A-Z0-9_]+) = \{\n(    front = \{[^\n]+\},)\n  \},$",
    re.MULTILINE,
)


def existing_kanto_metadata(root: Path) -> dict[str, str]:
    path = root / "data/animated_battle_sprites_gen2.lua"
    entries = dict(FRONT_ENTRY.findall(path.read_text(encoding="utf-8")))
    expected = {name for name, _ in roster(root)[:151]}
    if not expected.issubset(entries):
        raise ValueError("existing Gen 2 metadata lacks Kanto species")
    return {name: entries[name] for name, _ in roster(root)[:151]}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--base-url", default=SOURCE)
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()
    root = args.root.resolve()
    species = roster(root)
    old = existing_kanto_metadata(root)

    front_dir = root / "assets/battle/front-animated/gen2"
    source_dir = front_dir / "_source"
    back_dir = root / "assets/battle/back-static/gen2"
    source_dir.mkdir(parents=True, exist_ok=True)
    back_dir.mkdir(parents=True, exist_ok=True)
    records = [(name, old[name]) for name, _ in species[:151]]

    for number, (name, slug) in enumerate(species[151:], 152):
        source_path = source_dir / f"{slug}.apng"
        front_title = f"Spr 2c {number:03d}.png"
        front_raw, _ = fetch_candidates(
            source_path, args.base_url, [front_title], args.force
        )
        source_path.write_bytes(front_raw)
        info = convert(front_raw, front_dir / f"{slug}.png")
        relative = f"assets/battle/front-animated/gen2/{slug}.png"
        records.append(
            (name, f"    front = {lua_definition(relative, info)},")
        )

        back_path = back_dir / f"{slug}.png"
        back_title = f"Spr b 2c {number:03d}.png"
        back_raw, _ = fetch_candidates(
            back_path, args.base_url, [back_title], args.force, static=True
        )
        with Image.open(BytesIO(back_raw)) as image:
            size = image.size
            if getattr(image, "n_frames", 1) != 1:
                raise ValueError(f"{back_title}: expected one static frame")
            image.verify()
        back_path.write_bytes(back_raw)
        print(
            f"[{number:03d}/251] {slug:<12s} front={info['frames']:>2d}f "
            f"back={size[0]}x{size[1]}",
            flush=True,
        )

    lines = [
        "-- Generated/extended by tools/import_crystal_extended_normal_sprites.py.",
        "-- Pokemon Crystal animated fronts, National Dex #001-#251.",
        "return {",
    ]
    for name, definition in records:
        lines.extend((f"  {name} = {{", definition, "  },"))
    lines.append("}")
    metadata = root / "data/animated_battle_sprites_gen2.lua"
    metadata.write_text("\n".join(lines) + "\n", encoding="utf-8")

    for directory in (front_dir, back_dir):
        if len(list(directory.glob("*.png"))) != 251 \
                or not (directory / "bulbasaur.png").is_file() \
                or not (directory / "celebi.png").is_file():
            raise RuntimeError(f"incomplete Crystal collection in {directory}")
    print("wrote complete normal Crystal front/back collections through Celebi")


if __name__ == "__main__":
    main()
