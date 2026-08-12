"""Import Black/White shiny static backs through National Dex #386.

Pokemon Database uses species-name URLs. Deoxys Normal, Attack, Defense, and
Speed Formes are downloaded separately while the ordinary runtime slot remains
`deoxys.png`.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from import_animated_sprites import download
from import_gen5_extended_normal_sprites import (
    cached_download,
    canonical_roster,
    remote_slug,
    validate_static,
)


SOURCE = "https://img.pokemondb.net/sprites/black-white/back-shiny"


def fetch(destination: Path, base: str, remote: str, force: bool) -> tuple[int, int]:
    raw = cached_download(destination, f"{base.rstrip('/')}/{remote}.png", force)
    size = validate_static(raw, destination.stem)
    destination.write_bytes(raw)
    return size


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--base-url", default=SOURCE)
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()
    root = args.root.resolve()
    destination = root / "assets/battle/back-static/gen5/shiny"
    destination.mkdir(parents=True, exist_ok=True)

    for number, (_, slug) in enumerate(canonical_roster(root), 1):
        size = fetch(
            destination / f"{slug}.png",
            args.base_url,
            remote_slug(slug),
            args.force,
        )
        print(f"[{number:03d}/386] {slug:<12s} {size[0]}x{size[1]}", flush=True)

    for slug in ("deoxys-attack", "deoxys-defense", "deoxys-speed"):
        size = fetch(
            destination / f"{slug}.png", args.base_url, slug, args.force
        )
        print(f"[form] {slug:<14s} {size[0]}x{size[1]}", flush=True)

    files = list(destination.glob("*.png"))
    required = (
        "bulbasaur.png", "deoxys.png", "deoxys-attack.png",
        "deoxys-defense.png", "deoxys-speed.png",
    )
    if len(files) != 389 or any(
        not (destination / filename).is_file() for filename in required
    ):
        raise RuntimeError("incomplete Gen 5 shiny static-back collection")
    print("wrote 386 shiny static backs plus three alternate Deoxys formes")


if __name__ == "__main__":
    main()
