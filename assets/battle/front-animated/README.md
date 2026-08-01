# Front animated battle art

Optional animated opponent/player-front battle atlases go here. Local PNG
files are ignored by Git. The decoder expects the atlas cell dimensions and
frame timings recorded in `data/animated_battle_sprites.lua`; the supplied
metadata recognizes the atlases produced by
`tools/import_animated_back_sprite.py`. Missing or malformed art falls back to
the ROM sprite for that Pokemon.

GIF decoding is authoring-only. The game reads PNG atlases, extracts every
cell at its native logical resolution, and uses nearest-neighbour filtering.
The importer creates both the atlases and their single shared metadata file;
users do not write one Lua file per Pokemon.

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

Trainer front pictures can never be animated and are not read from this
folder. Put every opponent trainer PNG in `../front-static/`, including while
`BATTLE ART` is set to `ANIMATED`.
