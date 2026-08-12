"""Extend ordinary Gen 3 back art from #151 through Deoxys.

Existing Kanto files and metadata are preserved. National Dex #152-386 use
Emerald `Spr b 3e` animated backs and Ruby/Sapphire `Spr b 3r` static backs,
with bare, male, then female title priority. Deoxys uses Emerald Speed Forme
(`386S`) for the ordinary DEOXYS slot.

Emerald has no animated Defense Forme back. FireRed's static `386D` image is
therefore copied to `deoxys-d.png` and converted to a valid one-frame atlas,
with DEOXYS_D and DEOXYS_DEFENSE metadata aliases.
"""

from __future__ import annotations

import argparse
import re
from io import BytesIO
from pathlib import Path

from PIL import Image

from import_animated_sprites import convert, lua_definition
from import_emerald_shiny_sprites import roster
from import_gen4_extended_and_shiny_sprites import fetch_candidates


SOURCE = "https://archives.bulbagarden.net/wiki/Special:Redirect/file"
BACK_ENTRY = re.compile(
    r"^  ([A-Z0-9_]+) = \{\n(    back = \{[^\n]+\},)\n  \},$",
    re.MULTILINE,
)


def numbered(number: int) -> str:
    return "386S" if number == 386 else f"{number:03d}"


def gendered(prefix: str, number: int) -> list[str]:
    dex = numbered(number)
    return [
        f"{prefix} {dex}.png",
        f"{prefix} {dex} m.png",
        f"{prefix} {dex} f.png",
    ]


def existing_kanto_metadata(root: Path) -> dict[str, str]:
    path = root / "data/animated_battle_backs_gen3.lua"
    entries = dict(BACK_ENTRY.findall(path.read_text(encoding="utf-8")))
    expected = {name for name, _ in roster(root)[:151]}
    if not expected.issubset(entries):
        raise ValueError("existing Gen 3 back metadata lacks Kanto species")
    return {name: entries[name] for name, _ in roster(root)[:151]}


def static_details(raw: bytes, label: str) -> tuple[int, int, str]:
    with Image.open(BytesIO(raw)) as image:
        if getattr(image, "n_frames", 1) != 1:
            raise ValueError(f"{label}: expected a static PNG")
        details = image.width, image.height, image.mode
        image.verify()
    return details


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--base-url", default=SOURCE)
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()

    root = args.root.resolve()
    species = roster(root)
    old = existing_kanto_metadata(root)
    animated_dir = root / "assets/battle/back-animated/gen3"
    source_dir = animated_dir / "_source"
    static_dir = root / "assets/battle/back-static/gen3"
    source_dir.mkdir(parents=True, exist_ok=True)
    static_dir.mkdir(parents=True, exist_ok=True)
    records = [(name, old[name]) for name, _ in species[:151]]

    for number, (name, slug) in enumerate(species[151:], 152):
        source_path = source_dir / f"{slug}.apng"
        animated_raw, animated_title = fetch_candidates(
            source_path,
            args.base_url,
            gendered("Spr b 3e", number),
            args.force,
        )
        source_path.write_bytes(animated_raw)
        animated_path = animated_dir / f"{slug}.png"
        info = convert(
            animated_raw,
            animated_path,
            coalesce=True,
            minimum_duration=33,
        )
        relative = f"assets/battle/back-animated/gen3/{slug}.png"
        records.append(
            (name, f"    back = {lua_definition(relative, info, stable_anchor=True)},")
        )

        static_path = static_dir / f"{slug}.png"
        static_titles = (
            ["Spr b 3r 386.png"] if number == 386
            else gendered("Spr b 3r", number)
        )
        static_raw, static_title = fetch_candidates(
            static_path,
            args.base_url,
            static_titles,
            args.force,
            static=True,
        )
        static_path.write_bytes(static_raw)
        width, height, mode = static_details(static_raw, static_title)
        print(
            f"[{number:03d}/386] {slug:<12s} animated={animated_title} "
            f"({info['frames']}f); static={static_title} "
            f"({width}x{height} {mode})",
            flush=True,
        )

    # Defense Forme compatibility: a one-frame animated definition is valid
    # input for the same atlas decoder and avoids pretending static art moves.
    defense_static = static_dir / "deoxys-d.png"
    defense_raw, defense_title = fetch_candidates(
        defense_static,
        args.base_url,
        ["Spr b 3f 386D.png"],
        args.force,
        static=True,
    )
    defense_static.write_bytes(defense_raw)
    defense_animated = animated_dir / "deoxys-d.png"
    defense_info = convert(defense_raw, defense_animated)
    defense_rel = "assets/battle/back-animated/gen3/deoxys-d.png"
    defense_definition = (
        f"    back = {lua_definition(defense_rel, defense_info, stable_anchor=True)},"
    )
    records.extend((
        ("DEOXYS_D", defense_definition),
        ("DEOXYS_DEFENSE", defense_definition),
    ))

    lines = [
        "-- Generated/extended by tools/import_gen3_extended_back_sprites.py.",
        "-- Ordinary Gen 3 animated backs, National Dex #001-#386.",
        "return {",
    ]
    for name, definition in records:
        lines.extend((f"  {name} = {{", definition, "  },"))
    lines.append("}")
    metadata = root / "data/animated_battle_backs_gen3.lua"
    metadata.write_text("\n".join(lines) + "\n", encoding="utf-8")

    for directory in (animated_dir, static_dir):
        if len(list(directory.glob("*.png"))) != 387 \
                or not (directory / "bulbasaur.png").is_file() \
                or not (directory / "deoxys.png").is_file() \
                or not (directory / "deoxys-d.png").is_file():
            raise RuntimeError(f"incomplete Gen 3 back collection in {directory}")
    print(
        f"wrote 386 species plus Defense Deoxys fallback from {defense_title}"
    )


if __name__ == "__main__":
    main()
