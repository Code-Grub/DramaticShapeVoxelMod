# Back animated battle art

Reserved for optional animated player-back atlases. Local PNG files are
ignored by Git. Authored back art faces right and is never mirrored. Until an
atlas is recognized, BATTLE ART: ANIMATED falls back to the ROM.

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
