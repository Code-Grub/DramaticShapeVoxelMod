"""Extend ordinary Emerald animated fronts through National Dex #386.

Existing Kanto files and metadata are preserved. Chikorita through Deoxys use
Emerald `Spr 3e` APNGs with bare, male, then female priority. The ordinary
DEOXYS slot uses Speed Forme (`386S`). Emerald has no animated Defense Forme,
so FireRed's static `Spr 3f 386D` becomes a valid one-frame compatibility
atlas with DEOXYS_D and DEOXYS_DEFENSE metadata aliases.
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path

from import_animated_sprites import convert, lua_definition
from import_emerald_shiny_sprites import roster
from import_gen4_extended_and_shiny_sprites import fetch_candidates


SOURCE = "https://archives.bulbagarden.net/wiki/Special:Redirect/file"
FRONT_ENTRY = re.compile(
    r"^  ([A-Z0-9_]+) = \{\n(    front = \{[^\n]+\},)\n  \},$",
    re.MULTILINE,
)


def numbered(number: int) -> str:
    return "386S" if number == 386 else f"{number:03d}"


def gendered(number: int) -> list[str]:
    dex = numbered(number)
    return [
        f"Spr 3e {dex}.png",
        f"Spr 3e {dex} m.png",
        f"Spr 3e {dex} f.png",
    ]


def existing_kanto_metadata(root: Path) -> dict[str, str]:
    path = root / "data/animated_battle_sprites_gen3.lua"
    entries = dict(FRONT_ENTRY.findall(path.read_text(encoding="utf-8")))
    expected = {name for name, _ in roster(root)[:151]}
    if not expected.issubset(entries):
        raise ValueError("existing Gen 3 front metadata lacks Kanto species")
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

    destination = root / "assets/battle/front-animated/gen3"
    source_dir = destination / "_source"
    source_dir.mkdir(parents=True, exist_ok=True)
    records = [(name, old[name]) for name, _ in species[:151]]

    for number, (name, slug) in enumerate(species[151:], 152):
        source_path = source_dir / f"{slug}.apng"
        raw, selected = fetch_candidates(
            source_path, args.base_url, gendered(number), args.force
        )
        source_path.write_bytes(raw)
        info = convert(
            raw,
            destination / f"{slug}.png",
            coalesce=True,
            minimum_duration=33,
        )
        relative = f"assets/battle/front-animated/gen3/{slug}.png"
        records.append(
            (name, f"    front = {lua_definition(relative, info)},")
        )
        print(
            f"[{number:03d}/386] {slug:<12s} {selected} "
            f"{info['frames']}f {info['width']}x{info['height']}",
            flush=True,
        )

    defense_source = source_dir / "deoxys-d.png"
    defense_raw, defense_title = fetch_candidates(
        defense_source,
        args.base_url,
        ["Spr 3f 386D.png"],
        args.force,
        static=True,
    )
    defense_source.write_bytes(defense_raw)
    defense_info = convert(defense_raw, destination / "deoxys-d.png")
    defense_relative = "assets/battle/front-animated/gen3/deoxys-d.png"
    defense_definition = (
        f"    front = {lua_definition(defense_relative, defense_info)},"
    )
    records.extend((
        ("DEOXYS_D", defense_definition),
        ("DEOXYS_DEFENSE", defense_definition),
    ))

    lines = [
        "-- Generated/extended by tools/import_gen3_extended_front_sprites.py.",
        "-- Ordinary Emerald animated fronts, National Dex #001-#386.",
        "return {",
    ]
    for name, definition in records:
        lines.extend((f"  {name} = {{", definition, "  },"))
    lines.append("}")
    metadata = root / "data/animated_battle_sprites_gen3.lua"
    metadata.write_text("\n".join(lines) + "\n", encoding="utf-8")

    if len(list(destination.glob("*.png"))) != 387 \
            or not (destination / "bulbasaur.png").is_file() \
            or not (destination / "deoxys.png").is_file() \
            or not (destination / "deoxys-d.png").is_file():
        raise RuntimeError("incomplete Emerald animated front collection")
    print(
        f"wrote 386 species plus Defense Deoxys fallback from {defense_title}"
    )


if __name__ == "__main__":
    main()
