"""Import the Silver Shiny static front sprites, National Dex #001-#251.

Source category: https://archives.bulbagarden.net/wiki/Category:Silver_Shiny_sprites
Archive files follow the convention  Spr_2s_NNN_s.png  (NNN = zero-padded
National Dex number). We resolve them through Special:Redirect/file so we do
not depend on the per-upload hash in /media/upload/<hash>/<file>.

Sprites are written to  gen2-ideas/front-animated/gen1/shiny/<slug>.png
named by the species slug (matching the rest of the mod's sprite naming),
NOT into assets/battle (which is .gitignore-protected shipped art). This is a
staging/ideas folder you can review before promoting anything into release art.

These are single static PNGs, so no APNG atlas packing is performed -- the
bytes from the archive are stored verbatim (after a PNG validity check).
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

# Special:Redirect avoids the per-upload hash in /media/upload/<hash>/<file>.
REDIRECT = "https://archives.bulbagarden.net/wiki/Special:Redirect/file"

# National Dex 152-251 (Johto). Kanto (001-151) comes from the checked-in Gen 5
# metadata so all importers share its established engine ids and filename slugs.
# Each line:  ENGINE_NAME  slug
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
SNUBBERT snubbull
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

KANTO_ENTRY = re.compile(
    r'^  ([A-Z0-9_]+) = \{\n'
    r'    front = \{ image = "assets/battle/front-animated/gen5/([^/]+)\.png"',
    re.MULTILINE,
)


def roster(root: Path) -> list[tuple[int, str, str]]:
    """Return [(national_dex, engine_name, slug), ...] for #001-#251."""
    source = (root / "data/animated_battle_sprites_gen5.lua").read_text(
        encoding="utf-8"
    )
    kanto = KANTO_ENTRY.findall(source)
    johto = [tuple(line.split()) for line in JOHTO.strip().splitlines()]
    combined = kanto + johto
    if len(kanto) != 151 or len(johto) != 100 or len(combined) != 251:
        raise ValueError(
            f"expected 151 Kanto + 100 Johto species, got {len(kanto)} + {len(johto)}"
        )
    return [(n, name, slug) for n, (name, slug) in enumerate(combined, 1)]


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


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--base-url", default=REDIRECT)
    parser.add_argument("--force", action="store_true",
                        help="re-download even if the target PNG already exists")
    args = parser.parse_args()

    root = args.root.resolve()
    out_dir = root / "gen2-ideas/front-animated/gen1/shiny"
    out_dir.mkdir(parents=True, exist_ok=True)

    for number, engine_name, slug in roster(root):
        out_path = out_dir / f"{slug}.png"
        if out_path.is_file() and not args.force:
            try:
                if valid_png(out_path.read_bytes()):
                    print(f"[{number:03d}/251] {slug:<12s} cached", flush=True)
                    continue
            except Exception:
                pass
        raw = download(archive_url(args.base_url, f"Spr_2s_{number:03d}_s.png"))
        if not valid_png(raw):
            raise ValueError(
                f"#{number:03d} {slug}: archive response is not a valid PNG"
            )
        out_path.write_bytes(raw)
        print(f"[{number:03d}/251] {slug:<12s} wrote {len(raw)} bytes", flush=True)

    files = list(out_dir.glob("*.png"))
    expected = {"bulbasaur.png", "chikorita.png", "celebi.png"}
    missing = expected - {f.name for f in files}
    if len(files) != 251 or missing:
        raise RuntimeError(
            f"incomplete set: {len(files)} files, missing anchors {missing or 'none'}"
        )
    print(f"wrote 251 Silver Shiny sprites to {out_dir}")


if __name__ == "__main__":
    main()
