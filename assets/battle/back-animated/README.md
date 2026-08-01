# Back animated battle art

Optional animated player-back battle atlases are grouped here by generation.
Local PNG files are ignored by Git. Authored back art faces right and is never
mirrored. Gen 5 currently supplies `gen5/` back atlases; Gen 2 and Gen 3 have
front metadata only, so `PLAYER VIEW: BACK` falls back to the ROM back sprite
when either is selected in `BACK GEN`. This selector only affects ANIMATED
mode; static back PNGs remain freely replaceable and mix-and-match.

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

Trainer back pictures can never be animated and are not read from this
folder. Put `player.png`, `oak.png`, and `old-man.png` in `../back-static/`.
