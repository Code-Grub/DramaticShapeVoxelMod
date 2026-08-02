# Back animated battle art

Optional animated player-back battle atlases are grouped here by generation.
Local PNG files are ignored by Git. Authored back art faces right and is never
mirrored. Only GEN 5 uses animated back atlases here. `BACK ART SET` choices
GEN 1 through GEN 4 instead read single-frame PNGs from sibling folders
`../back-static/gen1` through `../back-static/gen4`, with no atlas processing.
Missing selected art retains the ROM back sprite in its original UI layer.
This selector only affects ANIMATED mode.

`BACK PLACEMENT` offers AUTO, WORLD, and OG UI. AUTO keeps a valid Gen 5 atlas
in the world and leaves a missing atlas's ROM fallback on OG UI. Forcing OG UI
is supported for comparison, but large atlas frames may crop there.

This folder also accepts five-pose player-trainer strips selected by the
`PLAYER ANIM` row in ANIMATED mode:

| Option | Filename |
| --- | --- |
| GEN 1 | `gen1player.png` |
| GEN 2 | `gen2player.png` |
| GEN 3 | `gen3player.png` |
| GEN 4 | `gen4player.png` |
| GEN 5 | `gen5player.png` |
| ASH | `ashplayer.png` |
| GARY | `garyplayer.png` |
| ROM | no file; use the engine portrait |

Each PNG is one horizontal row of exactly five equal-width frames. Existing
320-pixel strips are read as five 64-pixel cells; the recommended 400x80
format is five 80x80 cells. Copy poses into
`tools/player-animation-template-400x80.png`, but remove the coloured guide
dividers in the finished PNG. The first frame holds while the portrait is
stationary; frames two through five play once as the trainer slides left and
then stop. The animation never loops and is never resampled. Missing or
malformed selected art falls back to the ROM portrait. Under `BACK PLACEMENT:
AUTO`, player-trainer animation uses OG UI; WORLD and OG UI can override it.
Custom player frames remain 1x on OG UI, while its ROM fallback retains the
engine's intended 2x scale.

GIF decoding is authoring-only. The game reads PNG atlases, extracts every
cell at its native logical resolution, and uses nearest-neighbour filtering.
The importer creates both the atlases and the selected set's shared metadata;
users do not write one Lua file per Pokemon. Run
`python tools/import_animated_sprites.py --set gen5` from the repository root
to generate both Gen 5 fronts and backs.

## Gen 1 filename exceptions

Most species use their ordinary lowercase name (`pikachu.png`). These four
engine names need the following exact filenames:

| Species | Expected filename | Do not use |
| --- | --- | --- |
| Mr. Mime | `mr-mime.png` | `mrmime.png`, `mr.mime.png` |
| Farfetch’d | `farfetchd.png` | `farfetched.png`, `farfetch-d.png` |
| Nidoran♀ | `nidoran-f.png` | `nidoran.png`, `nidoran-female.png` |
| Nidoran♂ | `nidoran-m.png` | `nidoran.png`, `nidoran-male.png` |

Filenames are lowercase. The same names apply in every battle-art folder.

Opponent trainer pictures, Professor Oak, and Old Man are never animated.
Put `oak.png` and `old-man.png` in `../back-static/`; `player.png` is the
generic fallback used by STATIC-mode `PLAYER ART`.
