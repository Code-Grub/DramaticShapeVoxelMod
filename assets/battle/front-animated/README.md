# Front animated battle art

Optional animated opponent/player-front battle atlases are grouped here as
`gen2/`, `gen3/`, and `gen5/`. Local PNG files are ignored by Git. `ANIM SET`
chooses exactly one folder; missing or malformed art falls back to the ROM
sprite rather than silently mixing generations.

GIF decoding is authoring-only. The game reads PNG atlases, extracts every
cell at its native logical resolution, and uses nearest-neighbour filtering.
The importer creates both the atlases and the selected set's shared metadata;
users do not write one Lua file per Pokemon. From the repository root, run one
of `python tools/import_animated_sprites.py --set gen2`, `--set gen3`, or
`--set gen5`. Gen 2 uses Crystal fronts, Gen 3 uses Emerald fronts, and Gen 5
uses Black/White fronts.

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
