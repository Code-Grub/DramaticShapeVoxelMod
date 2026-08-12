"""Import Gen 3 shiny battle art, National Dex 001-386.

Emerald supplies the animated fronts and backs; FireRed supplies static
backs. Deoxys is version-specific: Emerald uses Speed Forme (386S), while
FireRed uses Attack Forme (386A). Both occupy the runtime `deoxys.png` slot.
"""

from __future__ import annotations

import argparse
import time
import urllib.parse
import urllib.request
from io import BytesIO
from pathlib import Path

from PIL import Image

from import_animated_sprites import convert, lua_definition
from import_crystal_shiny_sprites import roster as crystal_roster


SOURCE = "https://archives.bulbagarden.net/wiki/Special:Redirect/file"
HOENN_NAMES = """
treecko grovyle sceptile torchic combusken blaziken mudkip marshtomp swampert
poochyena mightyena zigzagoon linoone wurmple silcoon beautifly cascoon dustox
lotad lombre ludicolo seedot nuzleaf shiftry taillow swellow wingull pelipper
ralts kirlia gardevoir surskit masquerain shroomish breloom slakoth vigoroth
slaking nincada ninjask shedinja whismur loudred exploud makuhita hariyama
azurill nosepass skitty delcatty sableye mawile aron lairon aggron meditite
medicham electrike manectric plusle minun volbeat illumise roselia gulpin
swalot carvanha sharpedo wailmer wailord numel camerupt torkoal spoink grumpig
spinda trapinch vibrava flygon cacnea cacturne swablu altaria zangoose seviper
lunatone solrock barboach whiscash corphish crawdaunt baltoy claydol lileep
cradily anorith armaldo feebas milotic castform kecleon shuppet banette duskull
dusclops tropius chimecho absol wynaut snorunt glalie spheal sealeo walrein
clamperl huntail gorebyss relicanth luvdisc bagon shelgon salamence beldum
metang metagross regirock regice registeel latias latios kyogre groudon
rayquaza jirachi deoxys
""".split()


def engine_name(slug: str) -> str:
    return slug.replace("-", "_").upper()


def roster(root: Path) -> list[tuple[str, str]]:
    result = crystal_roster(root) + [(engine_name(slug), slug) for slug in HOENN_NAMES]
    if len(HOENN_NAMES) != 135 or len(result) != 386:
        raise ValueError(f"expected National Dex #001-#386, got {len(result)}")
    return result


def url(base: str, title: str) -> str:
    return f"{base.rstrip('/')}/{urllib.parse.quote(title)}"


def valid_png(raw: bytes) -> bool:
    try:
        if not raw.startswith(b"\x89PNG\r\n\x1a\n"):
            return False
        with Image.open(BytesIO(raw)) as image:
            image.verify()
        return True
    except Exception:
        return False


def fetch(path: Path, source_url: str, force: bool) -> bytes:
    if path.is_file() and not force:
        raw = path.read_bytes()
        if valid_png(raw):
            return raw
    request = urllib.request.Request(
        source_url,
        headers={"User-Agent": "DramaticShapeVoxelMod battle-art importer"},
    )
    for attempt in range(4):
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                raw = response.read()
            if not valid_png(raw):
                raise ValueError("archive response is not a PNG")
            return raw
        except Exception:
            if attempt == 3:
                raise
            time.sleep(1.5 * (attempt + 1))
    raise AssertionError("unreachable")


def number_for(number: int, collection: str) -> str:
    if number == 386:
        return "386S" if collection != "static" else "386A"
    return f"{number:03d}"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--base-url", default=SOURCE)
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()
    root = args.root.resolve()

    front_dir = root / "assets/battle/front-animated/gen3/shiny"
    animated_back_dir = root / "assets/battle/back-animated/gen3/shiny"
    static_back_dir = root / "assets/battle/back-static/gen3/shiny"
    front_source = front_dir / "_source"
    back_source = animated_back_dir / "_source"
    for directory in (front_dir, animated_back_dir, static_back_dir,
                      front_source, back_source):
        directory.mkdir(parents=True, exist_ok=True)

    records = []
    for number, (name, slug) in enumerate(roster(root), 1):
        front_title = f"Spr 3e {number_for(number, 'front')} s.png"
        front_raw_path = front_source / f"{slug}.apng"
        front_raw = fetch(front_raw_path, url(args.base_url, front_title), args.force)
        front_raw_path.write_bytes(front_raw)
        front_info = convert(
            front_raw, front_dir / f"{slug}.png",
            coalesce=True, minimum_duration=33,
        )

        back_title = f"Spr b 3e {number_for(number, 'back')} s.png"
        back_raw_path = back_source / f"{slug}.apng"
        back_raw = fetch(back_raw_path, url(args.base_url, back_title), args.force)
        back_raw_path.write_bytes(back_raw)
        back_info = convert(
            back_raw, animated_back_dir / f"{slug}.png",
            coalesce=True, minimum_duration=33,
        )

        static_title = f"Spr b 3f {number_for(number, 'static')} s.png"
        static_path = static_back_dir / f"{slug}.png"
        static_raw = fetch(static_path, url(args.base_url, static_title), args.force)
        with Image.open(BytesIO(static_raw)) as image:
            size = image.size
            frames = getattr(image, "n_frames", 1)
            if frames != 1 or not (1 <= image.width <= 256 and 1 <= image.height <= 256):
                raise ValueError(f"#{number:03d}: invalid static back {size}")
        static_path.write_bytes(static_raw)

        front_rel = f"assets/battle/front-animated/gen3/shiny/{slug}.png"
        back_rel = f"assets/battle/back-animated/gen3/shiny/{slug}.png"
        records.append((name, front_rel, front_info, back_rel, back_info))
        print(
            f"[{number:03d}/386] {slug:<12s} front={front_info['frames']:>2d}f "
            f"back={back_info['frames']:>2d}f static={size[0]}x{size[1]}",
            flush=True,
        )

    lines = [
        "-- Generated by tools/import_emerald_shiny_sprites.py.",
        "-- Gen 3 shiny animated fronts/backs, National Dex #001-#386.",
        "return {",
    ]
    for name, front_path, front_info, back_path, back_info in records:
        lines.extend((
            f"  {name} = {{",
            f"    front = {lua_definition(front_path, front_info)},",
            f"    back = {lua_definition(back_path, back_info, stable_anchor=True)},",
            "  },",
        ))
    lines.append("}")
    metadata = root / "data/animated_battle_sprites_gen3_shiny.lua"
    metadata.write_text("\n".join(lines) + "\n", encoding="utf-8")

    for directory in (front_dir, animated_back_dir, static_back_dir):
        if len(list(directory.glob("*.png"))) != 386 \
                or not (directory / "bulbasaur.png").is_file() \
                or not (directory / "deoxys.png").is_file():
            raise RuntimeError(f"incomplete Bulbasaur-Deoxys set in {directory}")
    print(f"wrote 386 fronts, 386 animated backs, 386 static backs, and {metadata}")


if __name__ == "__main__":
    main()
