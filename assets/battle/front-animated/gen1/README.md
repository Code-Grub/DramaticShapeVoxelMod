# Generation 1 front compatibility set

This folder supplies single-frame Gen 1, Super Game Boy, and ROM-hack front
sprites for `BATTLE ART: ANIMATED` with `ANIM FRONT GEN: GEN 1`. Unlike
the Gen 2–5 collections, these are ordinary PNGs rather than animation
atlases: no Lua sidecar, frame grid, or timing metadata is required.

Name one PNG per species using the same lowercase names as the other
battle-art folders, for example `pikachu.png`, `farfetchd.png`,
`mr-mime.png`, `nidoran-f.png`, and `nidoran-m.png`. Author opponent art
facing left. Missing or malformed species should fall back directly to the
ROM front sprite rather than borrow from another generation.

The Pokémon images are independent of the player-trainer introduction. A
five-frame player strip selected by `PLAYER ANIM` can therefore continue to
play while Pokémon fronts from this folder remain single-frame.

## Placement

The intended `FRONT PLACEMENT` choices are:

- `AUTO` — world placement during staged battles.
- `WORLD` — a world card with depth occlusion, alpha-shaped shadow, battle
  effects, and display filtering.
- `OG UI` — the original fixed battle slot and its UI-layer movement/effects.

Large or unusually padded art may crop when forced into `OG UI`; native
Game Boy and Super Game Boy dimensions are the natural fit there.

Front Pokémon remain world-placed in the current renderer. A separate
`FRONT PLACEMENT` selector is not implemented yet; the placement list above
documents the intended follow-up behavior rather than a current menu row.

Local artwork in this folder is ignored by Git and is not covered by the
mod's MIT license. Verify that you have the right to use and distribute it.
