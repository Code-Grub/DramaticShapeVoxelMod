# Back static battle art

Drop `<species>.png` player back sprites here. Art is used as authored and is
not mirrored; it should face right toward the opponent. Files may use any
pixel dimensions and require no Lua or metadata.

These local PNGs are ignored by Git. Missing or invalid files fall back to the
ROM sprite.

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
