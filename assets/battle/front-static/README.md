# Front static battle art

Drop `<species>.png` files here, for example `caterpie.png` or `mr-mime.png`.
Files may use any pixel dimensions. Existing alpha is preserved; a fully
opaque image has its corner-coloured, border-connected background keyed out.

These local PNGs are ignored by Git. Missing or invalid files fall back to the
ROM sprite. Enemy sprites are used as authored (facing left).

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
