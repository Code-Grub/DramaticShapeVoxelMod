"""Extract a purchased 10-column Kanto art sheet into static battle PNGs.

The source artwork is expected to use the regular 150-entry grid found in
Pokemon_Sugimori_151_18x24.jpg, followed by Mew centered on the final row.
All drawings share one scale factor so their relative sizes are preserved.
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter


REFERENCE_WIDTH = 5400
REFERENCE_HEIGHT = 7200
REFERENCE_ROW_BOUNDS = (
    0, 513, 957, 1404, 1930, 2492, 2923, 3381,
    3822, 4231, 4677, 5174, 5633, 6083, 6485, 6852,
)
ENTRY = re.compile(
    r'^  ([A-Z0-9_]+) = \{\n'
    r'    front = \{ image = "assets/battle/front-animated/gen5/([^/]+)\.png"',
    re.MULTILINE,
)

# Populate after reviewing the labelled contact sheet. Entries here are
# mirrored only when the purchased drawing clearly faces right.
FLIP_DEX: set[int] = {
    # 001-030, reviewed against the purchased sheet.
    1, 4, 8, 10, 12, 13, 14, 18, 19, 23, 26, 27, 28,
    # 031-060, reviewed against the purchased sheet.
    31, 37, 41, 42, 43, 44, 45, 46, 47, 48, 49, 51, 52, 53, 54, 56, 59,
    # 061-090, reviewed against the purchased sheet.
    63, 70, 71, 72, 73, 74, 78, 81, 83, 88,
    # 091-120, reviewed against the purchased sheet.
    91, 93, 95, 96, 99, 104, 109, 119,
    # 121-151, reviewed against the purchased sheet.
    123, 126, 129, 130, 132, 133, 136, 137, 140, 144, 145, 150, 151,
}

# Species with a detached artifact introduced by the collage layout. This is
# intentionally opt-in because detached particles are legitimate artwork for
# species such as Gastly and Koffing.
RETAIN_LARGEST_COMPONENT_DEX: set[int] = {149}


def species(root: Path) -> list[str]:
    source = (root / "data" / "animated_battle_sprites_gen5.lua").read_text(
        encoding="utf-8"
    )
    entries = ENTRY.findall(source)
    if len(entries) != 151:
        raise ValueError(f"expected 151 Kanto species definitions, got {len(entries)}")
    return [slug for _, slug in entries]


def smoothstep(values: np.ndarray) -> np.ndarray:
    values = np.clip(values, 0.0, 1.0)
    return values * values * (3.0 - 2.0 * values)


def matte(rgb: np.ndarray, key: np.ndarray) -> Image.Image:
    distance = np.max(np.abs(rgb.astype(np.float32) - key), axis=2)
    alpha_f = smoothstep((distance - 7.0) / (44.0 - 7.0))
    alpha = np.rint(alpha_f * 255.0).astype(np.uint8)

    # Remove the lavender composite color from partially transparent edge
    # pixels. This avoids a purple JPEG fringe after downsampling.
    safe_alpha = np.maximum(alpha_f[..., None], 1.0 / 255.0)
    foreground = (
        rgb.astype(np.float32) - (1.0 - alpha_f[..., None]) * key
    ) / safe_alpha
    foreground = np.clip(np.rint(foreground), 0, 255).astype(np.uint8)
    foreground[alpha == 0] = 0
    rgba = np.dstack((foreground, alpha))
    return Image.fromarray(rgba, "RGBA")


def horizontal_groups(mask: np.ndarray, gap: int) -> list[tuple[int, int]]:
    projection = mask.sum(axis=0)
    active = np.where(projection > 1)[0]
    if not len(active):
        return []
    groups: list[tuple[int, int]] = []
    start = previous = int(active[0])
    for position_raw in active[1:]:
        position = int(position_raw)
        if position - previous > gap:
            if projection[start:previous + 1].sum() > 250:
                groups.append((start, previous + 1))
            start = position
        previous = position
    if projection[start:previous + 1].sum() > 250:
        groups.append((start, previous + 1))
    return groups


def retain_largest_component(image: Image.Image) -> Image.Image:
    alpha = np.asarray(image.getchannel("A"))
    mask = alpha > 8
    height, width = mask.shape
    visited = np.zeros_like(mask, dtype=bool)
    components: list[list[tuple[int, int]]] = []
    for y in range(height):
        for x in range(width):
            if not mask[y, x] or visited[y, x]:
                continue
            stack = [(x, y)]
            visited[y, x] = True
            component: list[tuple[int, int]] = []
            while stack:
                px, py = stack.pop()
                component.append((px, py))
                for nx in range(max(0, px - 1), min(width, px + 2)):
                    for ny in range(max(0, py - 1), min(height, py + 2)):
                        if mask[ny, nx] and not visited[ny, nx]:
                            visited[ny, nx] = True
                            stack.append((nx, ny))
            components.append(component)
    if len(components) <= 1:
        return image
    largest = max(components, key=len)
    keep = Image.new("L", image.size)
    keep_pixels = keep.load()
    for x, y in largest:
        keep_pixels[x, y] = 255
    keep = keep.filter(ImageFilter.MaxFilter(5))
    rgba = np.asarray(image).copy()
    rgba[np.asarray(keep) == 0] = 0
    return Image.fromarray(rgba, "RGBA")


def extract(source: Path) -> tuple[list[Image.Image], tuple[int, int, int]]:
    with Image.open(source) as opened:
        rgb = np.asarray(opened.convert("RGB"))
    height, width = rgb.shape[:2]
    if (width, height) != (REFERENCE_WIDTH, REFERENCE_HEIGHT):
        raise ValueError(
            f"expected {REFERENCE_WIDTH}x{REFERENCE_HEIGHT}, got {width}x{height}"
        )

    border = np.concatenate((
        rgb[:32].reshape(-1, 3), rgb[-32:].reshape(-1, 3),
        rgb[:, :32].reshape(-1, 3), rgb[:, -32:].reshape(-1, 3),
    ))
    key = np.median(border, axis=0).astype(np.float32)
    distance = np.max(np.abs(rgb.astype(np.float32) - key), axis=2)
    foreground_mask = distance > 18.0

    drawings: list[Image.Image] = []
    for row, (top, bottom) in enumerate(
        zip(REFERENCE_ROW_BOUNDS, REFERENCE_ROW_BOUNDS[1:]), 1
    ):
        groups = horizontal_groups(foreground_mask[top:bottom], gap=40)
        if len(groups) != 10:
            raise ValueError(f"row {row} contains {len(groups)} drawings, expected 10")
        for left, right in groups:
            section = rgb[top:bottom, left:right]
            image = matte(section, key)
            box = image.getchannel("A").getbbox()
            if not box:
                raise ValueError(f"row {row} contains an empty drawing")
            drawings.append(image.crop(box))

    # The final band contains centered Mew and a seller signature at right.
    top = REFERENCE_ROW_BOUNDS[-1]
    groups = horizontal_groups(foreground_mask[top:], gap=40)
    center = width / 2.0
    mew_left, mew_right = min(
        groups, key=lambda group: abs(((group[0] + group[1]) / 2.0) - center)
    )
    mew = matte(rgb[top:, mew_left:mew_right], key)
    box = mew.getchannel("A").getbbox()
    if not box:
        raise ValueError("Mew extraction is empty")
    drawings.append(mew.crop(box))

    if len(drawings) != 151:
        raise ValueError(f"extracted {len(drawings)} drawings, expected 151")
    return drawings, tuple(int(round(value)) for value in key)


def save(
    drawings: list[Image.Image], names: list[str], output: Path, max_width: int
) -> float:
    widest = max(image.width for image in drawings)
    scale = min(1.0, max_width / widest)
    output.mkdir(parents=True, exist_ok=True)
    for number, (image, name) in enumerate(zip(drawings, names), 1):
        if number in FLIP_DEX:
            image = image.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        size = (
            max(1, round(image.width * scale)),
            max(1, round(image.height * scale)),
        )
        image = image.resize(size, Image.Resampling.LANCZOS)
        if number in RETAIN_LARGEST_COMPONENT_DEX:
            image = retain_largest_component(image)
        image.save(output / f"{name}.png", optimize=True)
    return scale


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--output", type=Path)
    parser.add_argument("--max-width", type=int, default=96)
    args = parser.parse_args()
    root = args.root.resolve()
    output = (args.output or root / "assets" / "battle" / "front-static").resolve()
    drawings, key = extract(args.source.resolve())
    scale = save(drawings, species(root), output, args.max_width)
    widths = [round(image.width * scale) for image in drawings]
    heights = [round(image.height * scale) for image in drawings]
    print(f"Extracted 151 PNGs into {output}")
    print(f"Background key: #{key[0]:02x}{key[1]:02x}{key[2]:02x}")
    print(f"Shared scale: {scale:.6f}")
    print(f"Output widths: {min(widths)}-{max(widths)} px")
    print(f"Output heights: {min(heights)}-{max(heights)} px")


if __name__ == "__main__":
    main()
