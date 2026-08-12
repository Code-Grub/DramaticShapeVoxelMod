"""Validate and normalise completed square battle backdrops.

Perspective-aware foreground extension is an image-authoring operation.  A
mechanical stretch of the bottom rows makes floors and fields appear to fold
over an edge, so this tool deliberately refuses rectangular source art.  First
outpaint that art to a complete square scene with a perspective-correct ground
plane and progressively blurred near foreground; this tool can then normalise
the finished image to the runtime 800x800 size.

It is safe to rerun: an existing 800x800 plate is left untouched unless
--force is given.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


OUTPUT_SIZE = (800, 800)


def extend(image: Image.Image) -> Image.Image:
    if image.width != image.height:
        raise ValueError(
            f"source is {image.width}x{image.height}; perspective-aware "
            "outpainting to a square image is required before normalising"
        )
    return image.convert("RGB").resize(OUTPUT_SIZE, Image.Resampling.LANCZOS)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("paths", nargs="+", type=Path)
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()

    changed = 0
    for root in args.paths:
        files = [root] if root.is_file() else sorted(root.rglob("*"))
        for path in files:
            if path.suffix.lower() not in {".jpg", ".jpeg", ".png"}:
                continue
            with Image.open(path) as source:
                if source.size == OUTPUT_SIZE and not args.force:
                    continue
                try:
                    output = extend(source)
                except ValueError as error:
                    parser.error(f"{path}: {error}")
            if path.suffix.lower() in {".jpg", ".jpeg"}:
                output.save(path, quality=92, subsampling=0, optimize=True)
            else:
                output.save(path, optimize=True)
            changed += 1
            print(path)
    print(f"normalised {changed} completed battle backdrop(s) to 800x800")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
