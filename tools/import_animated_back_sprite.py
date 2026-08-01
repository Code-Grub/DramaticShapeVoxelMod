"""Download and convert the original 151 Black/White battle animations.

The resulting PNG sheets are runtime assets; GIF decoding and network access
remain authoring-only. Both normal front and back-normal collections are
imported, and a Lua metadata table is generated alongside them.
"""

from __future__ import annotations

import argparse
import math
import time
import urllib.request
from io import BytesIO
from pathlib import Path

from PIL import Image, ImageSequence


KANTO = """
BULBASAUR bulbasaur
IVYSAUR ivysaur
VENUSAUR venusaur
CHARMANDER charmander
CHARMELEON charmeleon
CHARIZARD charizard
SQUIRTLE squirtle
WARTORTLE wartortle
BLASTOISE blastoise
CATERPIE caterpie
METAPOD metapod
BUTTERFREE butterfree
WEEDLE weedle
KAKUNA kakuna
BEEDRILL beedrill
PIDGEY pidgey
PIDGEOTTO pidgeotto
PIDGEOT pidgeot
RATTATA rattata
RATICATE raticate
SPEAROW spearow
FEAROW fearow
EKANS ekans
ARBOK arbok
PIKACHU pikachu
RAICHU raichu
SANDSHREW sandshrew
SANDSLASH sandslash
NIDORAN_F nidoran-f
NIDORINA nidorina
NIDOQUEEN nidoqueen
NIDORAN_M nidoran-m
NIDORINO nidorino
NIDOKING nidoking
CLEFAIRY clefairy
CLEFABLE clefable
VULPIX vulpix
NINETALES ninetales
JIGGLYPUFF jigglypuff
WIGGLYTUFF wigglytuff
ZUBAT zubat
GOLBAT golbat
ODDISH oddish
GLOOM gloom
VILEPLUME vileplume
PARAS paras
PARASECT parasect
VENONAT venonat
VENOMOTH venomoth
DIGLETT diglett
DUGTRIO dugtrio
MEOWTH meowth
PERSIAN persian
PSYDUCK psyduck
GOLDUCK golduck
MANKEY mankey
PRIMEAPE primeape
GROWLITHE growlithe
ARCANINE arcanine
POLIWAG poliwag
POLIWHIRL poliwhirl
POLIWRATH poliwrath
ABRA abra
KADABRA kadabra
ALAKAZAM alakazam
MACHOP machop
MACHOKE machoke
MACHAMP machamp
BELLSPROUT bellsprout
WEEPINBELL weepinbell
VICTREEBEL victreebel
TENTACOOL tentacool
TENTACRUEL tentacruel
GEODUDE geodude
GRAVELER graveler
GOLEM golem
PONYTA ponyta
RAPIDASH rapidash
SLOWPOKE slowpoke
SLOWBRO slowbro
MAGNEMITE magnemite
MAGNETON magneton
FARFETCHD farfetchd
DODUO doduo
DODRIO dodrio
SEEL seel
DEWGONG dewgong
GRIMER grimer
MUK muk
SHELLDER shellder
CLOYSTER cloyster
GASTLY gastly
HAUNTER haunter
GENGAR gengar
ONIX onix
DROWZEE drowzee
HYPNO hypno
KRABBY krabby
KINGLER kingler
VOLTORB voltorb
ELECTRODE electrode
EXEGGCUTE exeggcute
EXEGGUTOR exeggutor
CUBONE cubone
MAROWAK marowak
HITMONLEE hitmonlee
HITMONCHAN hitmonchan
LICKITUNG lickitung
KOFFING koffing
WEEZING weezing
RHYHORN rhyhorn
RHYDON rhydon
CHANSEY chansey
TANGELA tangela
KANGASKHAN kangaskhan
HORSEA horsea
SEADRA seadra
GOLDEEN goldeen
SEAKING seaking
STARYU staryu
STARMIE starmie
MR_MIME mr-mime
SCYTHER scyther
JYNX jynx
ELECTABUZZ electabuzz
MAGMAR magmar
PINSIR pinsir
TAUROS tauros
MAGIKARP magikarp
GYARADOS gyarados
LAPRAS lapras
DITTO ditto
EEVEE eevee
VAPOREON vaporeon
JOLTEON jolteon
FLAREON flareon
PORYGON porygon
OMANYTE omanyte
OMASTAR omastar
KABUTO kabuto
KABUTOPS kabutops
AERODACTYL aerodactyl
SNORLAX snorlax
ARTICUNO articuno
ZAPDOS zapdos
MOLTRES moltres
DRATINI dratini
DRAGONAIR dragonair
DRAGONITE dragonite
MEWTWO mewtwo
MEW mew
"""

SPECIES = [tuple(line.split()) for line in KANTO.strip().splitlines()]
BASE = "https://img.pokemondb.net/sprites/black-white/anim"


def download(url: str, retries: int = 4) -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    for attempt in range(retries):
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                return response.read()
        except Exception:
            if attempt + 1 == retries:
                raise
            time.sleep(1.5 * (attempt + 1))
    raise AssertionError("unreachable")


def convert(raw: bytes, destination: Path, columns: int = 16,
            max_dimension: int = 2048) -> dict:
    with Image.open(BytesIO(raw)) as gif:
        frames, durations = [], []
        for frame in ImageSequence.Iterator(gif):
            durations.append(int(frame.info.get("duration", gif.info.get("duration", 100))))
            frames.append(frame.convert("RGBA"))
    if not frames:
        raise ValueError("GIF contains no frames")
    width, height = frames[0].size
    if any(frame.size != (width, height) for frame in frames):
        raise ValueError("GIF frames do not share one logical canvas")
    max_columns = max_dimension // width
    if max_columns < 1:
        raise ValueError(f"frame width {width} exceeds {max_dimension}")
    columns = max(1, min(columns, max_columns, len(frames)))
    while math.ceil(len(frames) / columns) * height > max_dimension:
        columns += 1
        if columns > max_columns or columns > len(frames):
            raise ValueError(
                f"{len(frames)} {width}x{height} frames do not fit "
                f"within a {max_dimension}px sheet"
            )
    rows = math.ceil(len(frames) / columns)
    sheet = Image.new("RGBA", (columns * width, rows * height))
    for index, frame in enumerate(frames):
        sheet.alpha_composite(frame, ((index % columns) * width,
                                      (index // columns) * height))
    destination.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(destination, optimize=True)
    return {"width": width, "height": height, "columns": columns,
            "frames": len(frames), "durations": durations}


def lua_definition(path: str, info: dict) -> str:
    durations = ",".join(map(str, info["durations"]))
    return (f'{{ image = "{path}", width = {info["width"]}, '
            f'height = {info["height"]}, columns = {info["columns"]}, '
            f'frames = {info["frames"]}, durations = {{{durations}}} }}')


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path.cwd())
    args = parser.parse_args()
    root = args.root.resolve()
    records = {}
    for number, (species, slug) in enumerate(SPECIES, 1):
        records[species] = {}
        for side, remote in (("front", "normal"), ("back", "back-normal")):
            url = f"{BASE}/{remote}/{slug}.gif"
            relative = f"assets/battle/{side}-animated/{slug}.png"
            print(f"[{number:03d}/151] {side:5s} {slug}", flush=True)
            records[species][side] = convert(download(url), root / relative)
            records[species][side]["path"] = relative

    lines = ["-- Generated by tools/import_animated_back_sprite.py.",
             "-- Black/White animated front and back sprites, original 151.",
             "return {"]
    for species, _ in SPECIES:
        lines.append(f"  {species} = {{")
        for side in ("front", "back"):
            info = records[species][side]
            lines.append(f"    {side} = {lua_definition(info['path'], info)},")
        lines.append("  },")
    lines.append("}")
    destination = root / "data" / "animated_battle_sprites.lua"
    destination.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"wrote {destination} with {len(SPECIES) * 2} animations")


if __name__ == "__main__":
    main()
