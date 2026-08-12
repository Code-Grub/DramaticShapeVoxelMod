"""Import Crystal shiny fronts and Gen 2 shiny backs, National Dex 001-251.

Front APNGs are decoded and packed into the PNG atlas format consumed by
AnimatedBattleArt. Back sprites are single-frame PNGs and remain byte-for-byte
as supplied by Bulbagarden Archives. Stable Special:Redirect titles avoid the
per-file hashes used by media/upload URLs.
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

from import_animated_sprites import convert, lua_definition


SOURCE = "https://archives.bulbagarden.net/wiki/Special:Redirect/file"
KANTO_ENTRY = re.compile(
    r'^  ([A-Z0-9_]+) = \{\n'
    r'    front = \{ image = "assets/battle/front-animated/gen5/([^/]+)\.png"',
    re.MULTILINE,
)

# National Dex 152-251. Kanto comes from the checked-in Gen 5 metadata so all
# importers share its established engine ids and exceptional filename slugs.
JOHTO = """
CHIKORITA chikorita
BAYLEEF bayleef
MEGANIUM meganium
CYNDAQUIL cyndaquil
QUILAVA quilava
TYPHLOSION typhlosion
TOTODILE totodile
CROCONAW croconaw
FERALIGATR feraligatr
SENTRET sentret
FURRET furret
HOOTHOOT hoothoot
NOCTOWL noctowl
LEDYBA ledyba
LEDIAN ledian
SPINARAK spinarak
ARIADOS ariados
CROBAT crobat
CHINCHOU chinchou
LANTURN lanturn
PICHU pichu
CLEFFA cleffa
IGGLYBUFF igglybuff
TOGEPI togepi
TOGETIC togetic
NATU natu
XATU xatu
MAREEP mareep
FLAAFFY flaaffy
AMPHAROS ampharos
BELLOSSOM bellossom
MARILL marill
AZUMARILL azumarill
SUDOWOODO sudowoodo
POLITOED politoed
HOPPIP hoppip
SKIPLOOM skiploom
JUMPLUFF jumpluff
AIPOM aipom
SUNKERN sunkern
SUNFLORA sunflora
YANMA yanma
WOOPER wooper
QUAGSIRE quagsire
ESPEON espeon
UMBREON umbreon
MURKROW murkrow
SLOWKING slowking
MISDREAVUS misdreavus
UNOWN unown
WOBBUFFET wobbuffet
GIRAFARIG girafarig
PINECO pineco
FORRETRESS forretress
DUNSPARCE dunsparce
GLIGAR gligar
STEELIX steelix
SNUBBULL snubbull
GRANBULL granbull
QWILFISH qwilfish
SCIZOR scizor
SHUCKLE shuckle
HERACROSS heracross
SNEASEL sneasel
TEDDIURSA teddiursa
URSARING ursaring
SLUGMA slugma
MAGCARGO magcargo
SWINUB swinub
PILOSWINE piloswine
CORSOLA corsola
REMORAID remoraid
OCTILLERY octillery
DELIBIRD delibird
MANTINE mantine
SKARMORY skarmory
HOUNDOUR houndour
HOUNDOOM houndoom
KINGDRA kingdra
PHANPY phanpy
DONPHAN donphan
PORYGON2 porygon2
STANTLER stantler
SMEARGLE smeargle
TYROGUE tyrogue
HITMONTOP hitmontop
SMOOCHUM smoochum
ELEKID elekid
MAGBY magby
MILTANK miltank
BLISSEY blissey
RAIKOU raikou
ENTEI entei
SUICUNE suicune
LARVITAR larvitar
PUPITAR pupitar
TYRANITAR tyranitar
LUGIA lugia
HO_OH ho-oh
CELEBI celebi
"""


def roster(root: Path) -> list[tuple[str, str]]:
    source = (root / "data/animated_battle_sprites_gen5.lua").read_text(
        encoding="utf-8"
    )
    kanto = KANTO_ENTRY.findall(source)
    johto = [tuple(line.split()) for line in JOHTO.strip().splitlines()]
    result = kanto + johto
    if len(kanto) != 151 or len(johto) != 100 or len(result) != 251:
        raise ValueError(
            f"expected 151 Kanto + 100 Johto species, got {len(kanto)} + {len(johto)}"
        )
    return result


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


def archive_url(base: str, title: str) -> str:
    return f"{base.rstrip('/')}/{urllib.parse.quote(title)}"


def valid_png(raw: bytes) -> bool:
    if not raw.startswith(b"\x89PNG\r\n\x1a\n"):
        return False
    try:
        with Image.open(BytesIO(raw)) as image:
            image.verify()
        return True
    except Exception:
        return False


def existing_or_download(path: Path, url: str, force: bool) -> bytes:
    if path.is_file() and not force:
        raw = path.read_bytes()
        if valid_png(raw):
            return raw
    raw = download(url)
    if not valid_png(raw):
        raise ValueError(f"archive response is not a valid PNG: {url}")
    return raw


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--base-url", default=SOURCE)
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()

    root = args.root.resolve()
    front_dir = root / "assets/battle/front-animated/gen2/shiny"
    # Converted atlases are not valid source APNGs on a rerun. Keep the raw
    # archive payloads separately; .apng is ignored by Git and package_mod.ps1
    # includes only runtime .png/.jpg/.webp artwork.
    source_dir = front_dir / "_source"
    back_dir = root / "assets/battle/back-static/gen2/shiny"
    front_dir.mkdir(parents=True, exist_ok=True)
    source_dir.mkdir(parents=True, exist_ok=True)
    back_dir.mkdir(parents=True, exist_ok=True)
    records: list[tuple[str, str, dict]] = []

    for number, (engine_name, slug) in enumerate(roster(root), 1):
        front_out = front_dir / f"{slug}.png"
        front_source = source_dir / f"{slug}.apng"
        front_raw = existing_or_download(
            front_source,
            archive_url(args.base_url, f"Spr 2c {number:03d} s.png"),
            args.force,
        )
        front_source.write_bytes(front_raw)
        info = convert(front_raw, front_out)

        back_out = back_dir / f"{slug}.png"
        back_raw = existing_or_download(
            back_out,
            archive_url(args.base_url, f"Spr b 2g {number:03d} s.png"),
            args.force,
        )
        with Image.open(BytesIO(back_raw)) as image:
            width, height = image.size
            if width < 1 or height < 1 or width > 256 or height > 256:
                raise ValueError(f"#{number:03d} unreasonable back size {image.size}")
        back_out.write_bytes(back_raw)

        relative = f"assets/battle/front-animated/gen2/shiny/{slug}.png"
        records.append((engine_name, relative, info))
        print(
            f"[{number:03d}/251] {slug:<12s} front={info['frames']:>2d}f "
            f"back={width}x{height}",
            flush=True,
        )

    lines = [
        "-- Generated by tools/import_crystal_shiny_sprites.py.",
        "-- Pokemon Crystal shiny fronts, National Dex #001-#251.",
        "return {",
    ]
    for engine_name, path, info in records:
        lines.extend((f"  {engine_name} = {{", f"    front = {lua_definition(path, info)},", "  },"))
    lines.append("}")
    metadata = root / "data/animated_battle_sprites_gen2_shiny.lua"
    metadata.write_text("\n".join(lines) + "\n", encoding="utf-8")

    for directory in (front_dir, back_dir):
        files = list(directory.glob("*.png"))
        if len(files) != 251 or not (directory / "bulbasaur.png").is_file() \
                or not (directory / "celebi.png").is_file():
            raise RuntimeError(f"incomplete Bulbasaur-Celebi set in {directory}")
    print(f"wrote 251 front atlases, 251 back PNGs, and {metadata}")


if __name__ == "__main__":
    main()
