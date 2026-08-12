"""Extend ordinary Black/White battle art through National Dex #386.

The existing Kanto atlases and metadata are preserved. Chikorita through
Deoxys are downloaded from Pokemon Database as animated fronts, animated
backs, and static backs. Raw GIFs are retained below ignored `_source`
folders so reruns do not need to download unchanged animations.
"""

from __future__ import annotations

import argparse
import re
from io import BytesIO
from pathlib import Path

from PIL import Image

from import_animated_sprites import convert, download, lua_definition
from import_crystal_shiny_sprites import JOHTO
from import_emerald_shiny_sprites import HOENN_NAMES, engine_name


ANIMATED_SOURCE = "https://img.pokemondb.net/sprites/black-white/anim"
STATIC_SOURCE = "https://img.pokemondb.net/sprites/black-white/back-normal"
ENTRY = re.compile(
    r"^  ([A-Z0-9_]+) = \{\n"
    r"(    front = \{[^\n]+\},)\n"
    r"(    back = \{[^\n]+\},)\n"
    r"  \},$",
    re.MULTILINE,
)


def canonical_roster(root: Path) -> list[tuple[str, str]]:
    """Build #001-#386 without assuming Gen 5 metadata is still Kanto-only."""
    path = root / "data/animated_battle_sprites_gen5.lua"
    entries = ENTRY.findall(path.read_text(encoding="utf-8"))
    kanto = [
        (name, re.search(r"gen5/([^/]+)\.png", front).group(1))
        for name, front, _ in entries[:151]
    ]
    johto = [tuple(line.split()) for line in JOHTO.strip().splitlines()]
    hoenn = [(engine_name(slug), slug) for slug in HOENN_NAMES]
    result = kanto + johto + hoenn
    if len(kanto) != 151 or len(result) != 386:
        raise ValueError(f"expected National Dex #001-#386, got {len(result)}")
    return result


def existing_kanto_metadata(
        root: Path, species: list[tuple[str, str]]
) -> dict[str, tuple[str, str]]:
    path = root / "data/animated_battle_sprites_gen5.lua"
    entries = {
        name: (front, back)
        for name, front, back in ENTRY.findall(path.read_text(encoding="utf-8"))
    }
    expected = {name for name, _ in species[:151]}
    if not expected.issubset(entries):
        raise ValueError("existing Gen 5 metadata lacks Kanto species")
    return entries


def remote_slug(slug: str) -> str:
    # Pokemon Database distinguishes the normal forme in its asset filename.
    return "deoxys-normal" if slug == "deoxys" else slug


def cached_download(path: Path, url: str, force: bool) -> bytes:
    if path.is_file() and not force:
        raw = path.read_bytes()
        if raw.startswith((b"GIF87a", b"GIF89a", b"\x89PNG\r\n\x1a\n")):
            return raw
    raw = download(url)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(raw)
    return raw


def validate_static(raw: bytes, slug: str) -> tuple[int, int]:
    if not raw.startswith(b"\x89PNG\r\n\x1a\n"):
        raise ValueError(f"{slug}: static back response is not a PNG")
    with Image.open(BytesIO(raw)) as image:
        if getattr(image, "n_frames", 1) != 1:
            raise ValueError(f"{slug}: expected one static back frame")
        size = image.size
        image.verify()
    return size


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--animated-base-url", default=ANIMATED_SOURCE)
    parser.add_argument("--static-base-url", default=STATIC_SOURCE)
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()
    root = args.root.resolve()
    species = canonical_roster(root)
    old = existing_kanto_metadata(root, species)

    front_dir = root / "assets/battle/front-animated/gen5"
    back_dir = root / "assets/battle/back-animated/gen5"
    static_dir = root / "assets/battle/back-static/gen5"
    front_source = front_dir / "_source"
    back_source = back_dir / "_source"
    for directory in (front_dir, back_dir, static_dir, front_source, back_source):
        directory.mkdir(parents=True, exist_ok=True)

    records = [
        (name, *old[name])
        for name, _ in species[:151]
    ]
    animated_base = args.animated_base_url.rstrip("/")
    static_base = args.static_base_url.rstrip("/")

    for number, (name, slug) in enumerate(species[151:], 152):
        source_slug = remote_slug(slug)
        front_raw = cached_download(
            front_source / f"{slug}.gif",
            f"{animated_base}/normal/{source_slug}.gif",
            args.force,
        )
        back_raw = cached_download(
            back_source / f"{slug}.gif",
            f"{animated_base}/back-normal/{source_slug}.gif",
            args.force,
        )
        static_path = static_dir / f"{slug}.png"
        static_raw = cached_download(
            static_path,
            f"{static_base}/{source_slug}.png",
            args.force,
        )

        front_info = convert(front_raw, front_dir / f"{slug}.png")
        back_info = convert(back_raw, back_dir / f"{slug}.png")
        static_size = validate_static(static_raw, slug)
        static_path.write_bytes(static_raw)

        front_path = f"assets/battle/front-animated/gen5/{slug}.png"
        back_path = f"assets/battle/back-animated/gen5/{slug}.png"
        records.append((
            name,
            f"    front = {lua_definition(front_path, front_info)},",
            f"    back = {lua_definition(back_path, back_info)},",
        ))
        print(
            f"[{number:03d}/386] {slug:<12s} "
            f"front={front_info['frames']:>3d}f "
            f"back={back_info['frames']:>3d}f "
            f"static={static_size[0]}x{static_size[1]}",
            flush=True,
        )

    lines = [
        "-- Generated/extended by tools/import_gen5_extended_normal_sprites.py.",
        "-- Ordinary Black/White animated fronts/backs, National Dex #001-#386.",
        "return {",
    ]
    for name, front, back in records:
        lines.extend((f"  {name} = {{", front, back, "  },"))
    lines.append("}")
    metadata = root / "data/animated_battle_sprites_gen5.lua"
    metadata.write_text("\n".join(lines) + "\n", encoding="utf-8")

    for directory in (front_dir, back_dir, static_dir):
        images = list(directory.glob("*.png"))
        if len(images) != 386 \
                or not (directory / "chikorita.png").is_file() \
                or not (directory / "treecko.png").is_file() \
                or not (directory / "deoxys.png").is_file():
            raise RuntimeError(f"incomplete Chikorita-Deoxys set in {directory}")
    print(f"wrote 386 fronts, 386 animated backs, 386 static backs, and {metadata}")


if __name__ == "__main__":
    main()
