"""Extend ordinary Gen 4 art and import shiny art through National Dex #386.

Collections:
* ordinary Diamond/Pearl animated fronts (#152-386; preserves existing Kanto)
* ordinary Diamond/Pearl static backs (#152-386; preserves existing Kanto)
* shiny Diamond/Pearl animated fronts (#001-386)
* shiny Platinum static backs (#001-386, falling back to Diamond/Pearl)

Gender priority matches the existing Gen 4 front importer: canonical bare
title, then male, then female. Deoxys uses Speed Forme (`386S`).
"""

from __future__ import annotations

import argparse
import re
import time
import urllib.error
import urllib.parse
import urllib.request
from io import BytesIO
from pathlib import Path

from PIL import Image

from import_animated_sprites import convert, lua_definition
from import_emerald_shiny_sprites import roster


SOURCE = "https://archives.bulbagarden.net/wiki/Special:Redirect/file"
NORMAL_ENTRY = re.compile(
    r"^  ([A-Z0-9_]+) = \{\n(    front = \{[^\n]+\},)\n  \},$",
    re.MULTILINE,
)


def archive_url(base: str, title: str) -> str:
    return f"{base.rstrip('/')}/{urllib.parse.quote(title)}"


def valid_png(raw: bytes, *, static: bool = False) -> bool:
    try:
        if not raw.startswith(b"\x89PNG\r\n\x1a\n"):
            return False
        with Image.open(BytesIO(raw)) as image:
            if static and getattr(image, "n_frames", 1) != 1:
                return False
            image.verify()
        return True
    except Exception:
        return False


def download(source_url: str, retries: int = 4) -> bytes:
    request = urllib.request.Request(
        source_url,
        headers={"User-Agent": "DramaticShapeVoxelMod battle-art importer"},
    )
    for attempt in range(retries):
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                return response.read()
        except urllib.error.HTTPError as exc:
            # A missing archive title is a real candidate miss; throttling or
            # a temporary server failure must retry this same valid title
            # instead of incorrectly advancing to another gender variant.
            if exc.code == 404 or attempt + 1 == retries:
                raise
            time.sleep(1.5 * (attempt + 1))
        except Exception:
            if attempt + 1 == retries:
                raise
            time.sleep(1.5 * (attempt + 1))
    raise AssertionError("unreachable")


def fetch_candidates(
    cache: Path,
    base: str,
    titles: list[str],
    force: bool,
    *,
    static: bool = False,
) -> tuple[bytes, str]:
    if cache.is_file() and not force:
        raw = cache.read_bytes()
        if valid_png(raw, static=static):
            return raw, "cached"
    errors = []
    for title in titles:
        try:
            raw = download(archive_url(base, title))
            if not valid_png(raw, static=static):
                raise ValueError("response is not a valid PNG")
            return raw, title
        except (urllib.error.URLError, ValueError) as exc:
            errors.append(f"{title}: {exc}")
    raise RuntimeError("; ".join(errors))


def numbered(number: int) -> str:
    return "386S" if number == 386 else f"{number:03d}"


def gendered(prefix: str, number: int, *, shiny: bool) -> list[str]:
    dex = numbered(number)
    ending = " s.png" if shiny else ".png"
    return [
        f"{prefix} {dex}{ending}",
        f"{prefix} {dex} m{ending}",
        f"{prefix} {dex} f{ending}",
    ]


def platinum_backs(number: int) -> list[str]:
    # Prefer the user's Platinum (`4p`) collection, then the shared or
    # redirected Diamond/Pearl (`4d`) file, with the same gender priority.
    choices = []
    for sex in ("", " m", " f"):
        dex = numbered(number)
        choices.append(f"Spr b 4p {dex}{sex} s.png")
        choices.append(f"Spr b 4d {dex}{sex} s.png")
    return choices


def existing_kanto_metadata(root: Path) -> dict[str, str]:
    path = root / "data/animated_battle_sprites_gen4.lua"
    entries = dict(NORMAL_ENTRY.findall(path.read_text(encoding="utf-8")))
    expected = {name for name, _ in roster(root)[:151]}
    if not expected.issubset(entries):
        raise ValueError("existing Gen 4 metadata does not contain all Kanto species")
    return {name: entries[name] for name, _ in roster(root)[:151]}


def write_metadata(path: Path, title: str, records: list[tuple[str, str]]) -> None:
    lines = [title, "return {"]
    for name, definition in records:
        lines.extend((f"  {name} = {{", definition, "  },"))
    lines.append("}")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--base-url", default=SOURCE)
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()
    root = args.root.resolve()
    species = roster(root)
    old_metadata = existing_kanto_metadata(root)

    normal_front = root / "assets/battle/front-animated/gen4"
    normal_source = normal_front / "_source"
    normal_back = root / "assets/battle/back-static/gen4"
    shiny_front = normal_front / "shiny"
    shiny_source = shiny_front / "_source"
    shiny_back = normal_back / "shiny"
    for directory in (normal_front, normal_source, normal_back, shiny_front,
                      shiny_source, shiny_back):
        directory.mkdir(parents=True, exist_ok=True)

    normal_records = [(name, old_metadata[name]) for name, _ in species[:151]]
    shiny_records = []
    for number, (name, slug) in enumerate(species, 1):
        if number >= 152:
            source_path = normal_source / f"{slug}.apng"
            raw, selected = fetch_candidates(
                source_path,
                args.base_url,
                gendered("Spr 4d", number, shiny=False),
                args.force,
            )
            source_path.write_bytes(raw)
            info = convert(raw, normal_front / f"{slug}.png")
            relative = f"assets/battle/front-animated/gen4/{slug}.png"
            normal_records.append((name, f"    front = {lua_definition(relative, info)},"))

            static_path = normal_back / f"{slug}.png"
            static_raw, static_selected = fetch_candidates(
                static_path,
                args.base_url,
                gendered("Spr b 4d", number, shiny=False),
                args.force,
                static=True,
            )
            static_path.write_bytes(static_raw)
        else:
            selected = static_selected = "preserved"

        shiny_source_path = shiny_source / f"{slug}.apng"
        shiny_raw, shiny_selected = fetch_candidates(
            shiny_source_path,
            args.base_url,
            gendered("Spr 4d", number, shiny=True),
            args.force,
        )
        shiny_source_path.write_bytes(shiny_raw)
        shiny_info = convert(shiny_raw, shiny_front / f"{slug}.png")
        shiny_relative = f"assets/battle/front-animated/gen4/shiny/{slug}.png"
        shiny_records.append(
            (name, f"    front = {lua_definition(shiny_relative, shiny_info)},")
        )

        shiny_back_path = shiny_back / f"{slug}.png"
        shiny_back_raw, back_selected = fetch_candidates(
            shiny_back_path,
            args.base_url,
            platinum_backs(number),
            args.force,
            static=True,
        )
        shiny_back_path.write_bytes(shiny_back_raw)
        print(
            f"[{number:03d}/386] {slug:<12s} normal={selected} / {static_selected}; "
            f"shiny={shiny_selected} / {back_selected}",
            flush=True,
        )

    write_metadata(
        root / "data/animated_battle_sprites_gen4.lua",
        "-- Generated/extended by tools/import_gen4_extended_and_shiny_sprites.py.",
        normal_records,
    )
    write_metadata(
        root / "data/animated_battle_sprites_gen4_shiny.lua",
        "-- Generated by tools/import_gen4_extended_and_shiny_sprites.py.",
        shiny_records,
    )
    for directory in (normal_front, normal_back, shiny_front, shiny_back):
        if len(list(directory.glob("*.png"))) != 386 \
                or not (directory / "bulbasaur.png").is_file() \
                or not (directory / "deoxys.png").is_file():
            raise RuntimeError(f"incomplete Bulbasaur-Deoxys set in {directory}")
    print("wrote complete normal and shiny Gen 4 collections through Deoxys")


if __name__ == "__main__":
    main()
