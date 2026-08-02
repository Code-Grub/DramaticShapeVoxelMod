# Back static battle art

Drop `<species>.png` player back sprites into a generation subfolder. Art is
used as authored and is not mirrored; it should face right toward the
opponent. Files may use any pixel dimensions and require no Lua or metadata.

These local PNGs are ignored by Git. Missing or invalid files fall back to the
ROM sprite.

## Generation sets

`BACK ART SET` selects one of these generation subfolders:

- `back-static/gen1/<species>.png`
- `back-static/gen2/<species>.png`
- `back-static/gen3/<species>.png`
- `back-static/gen4/<species>.png`
- `back-static/gen5/<species>.png`

Under `BATTLE ART: STATIC`, all five choices read only these ordinary PNGs.
Static GEN 5 never loads or decodes the similarly named animated atlas.

Under `BATTLE ART: ANIMATED`, GEN 1 through GEN 4 use the same single-frame
PNGs, while GEN 5 uses `back-animated/gen5`. If the selected file is absent or
invalid, the ROM backsprite is used instead. An absent `gen1` directory does
not remove GEN 1 from the menu; it is an intentional empty slot for ROM-hack
or other user-supplied artwork.

For a complete Gen 1 set with prepared transparency, the optional importer
downloads the 151 Pokemon Yellow Super Game Boy back sprites from
[Bulbagarden Archives](https://archives.bulbagarden.net/wiki/Category:Yellow_back_sprites_(Super_Game_Boy)):

```powershell
python tools/import_yellow_sgb_back_sprites.py --root .
```

It writes the source PNG bytes unchanged into `back-static/gen1`. The artwork
remains ignored by Git but is included by `tools/package_mod.ps1` in local test
ZIPs.

`BACK PLACEMENT` can override the layer for comparison. AUTO uses supplied
generation PNGs in the world and keeps a missing ANIMATED fallback on OG UI;
WORLD and OG UI force either presentation.

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

## Static player-side trainer backs

This folder supplies the static `PLAYER ART` portraits. ANIMATED mode instead
reads the five-pose player strips documented in `../back-animated/`. Professor
Oak and Old Man remain static and always resolve here:

| Battle role | Expected filename |
| --- | --- |
| `PLAYER ART: PNG` (default and named-set fallback) | `player.png` |
| `PLAYER ART: GEN 1` | `gen1player.png` |
| `PLAYER ART: GEN 2` | `gen2player.png` |
| `PLAYER ART: GEN 3` | `gen3player.png` |
| `PLAYER ART: GEN 4` | `gen4player.png` |
| `PLAYER ART: GEN 5` | `gen5player.png` |
| `PLAYER ART: ASH` | `ashplayer.png` |
| `PLAYER ART: GARY` | `garyplayer.png` |
| `PLAYER ART: ROM` | no file; retain the ROM portrait |
| Professor Oak in Yellow's opening battle | `oak.png` |
| Old Man catching tutorial | `old-man.png` |

These are intro trainer cards, not Pokémon species. A missing GEN/ASH/GARY
selection tries `player.png`, then retains the ROM trainer backsprite. PNG
tries `player.png` directly; ROM deliberately bypasses it. `PLAYER ART` is independent of species
`BATTLE ART`, so its ROM choice does not disable custom Pokémon or opponent
trainer art. Opponent trainers never read from a back folder.
