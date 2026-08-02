# DRAMATIC SHAPE VOXEL MOD BATTLE ART

A mod for the [Pokémon Gen 1 Recompilation
Project](https://github.com/bryanthaboi/pokemon-gen1-recomp-project).

The overworld as a 3D diorama. Terrain is extruded into real geometry,
occlusion comes from a depth buffer rather than a y-sort, characters stand
as leaning sprite slabs, a shadow map throws real cast shadows across
whatever they land on, and an optional tilt-shift pass sells the
miniature-model look.

And battles fought on that world rather than on a white field. When
something picks a fight the map's NPCs are culled, the engine's own wipe
plays over the empty map, and the battle draws over the nearest patch of
clear ground — shot over the shoulder, the player's mon low and left and
the enemy high and right, with a slow parallax drift behind them and a
depth-of-field pass that keeps both of them sharp.

Purely presentational. Nothing here reaches collision, movement, triggers
or scripts — it changes what the world *looks* like and nothing about what
it *is*. The battle arena is where the **camera** goes, not where anybody
goes: no cell, facing, flag or warp is written, so the player is standing
exactly where the fight found them when it ends.

## Controls

Every key is free-roam only, and each one is also a row on the OPTIONS
menu.

| control | does |
| --- | --- |
| `3`, or the **VOXEL** options row | OFF → 15 → 35 → 50 → 75 → OFF (camera pitch) |
| `5`, or the **V-GRID** options row | OFF / ON — a one-pixel wireframe on every voxel |
| `6`, or the **T-SHIFT** options row | OFF → 1 → 2 → 3 → OFF (miniature blur) |
| `7`, or the **V-CURVE** options row | OFF → 1 → 2 → 3 — bend the world over the horizon |
| `8`, or the **3D-BTL** options row | ON / OFF — fight on the map instead of on a white field |
| the **BATTLE ART** options row | STATIC / ANIMATED / ROM — use optional battle-only art, with a direct ROM fallback when a file or atlas is absent |
| the **TRAINER ART** options row | GEN 1 / GEN 2 / GEN 3 — choose a static opponent-trainer collection |
| the **PLAYER ART** options row | PNG / GEN 1 / GEN 2 / GEN 3 / GEN 4 / GEN 5 / ASH / GARY / ROM — choose the static player trainer battle-intro portrait; BATTLE ART: ROM pins it to ROM |
| the **PLAYER ANIM** options row | PNG / GEN 1 / GEN 2 / GEN 3 / GEN 4 / GEN 5 / ASH / GARY / ROM — choose a static `player.png` or five-pose player intro while ANIMATED is selected |
| the **ANIM FRONT GEN** options row | GEN 1 / GEN 2 / GEN 3 / GEN 4 / GEN 5 — choose a single-frame Gen 1 compatibility set or an animated Gen 2–5 collection |
| the **BACK ART SET** options row | GEN 1 / GEN 2 / GEN 3 / GEN 4 / GEN 5 — STATIC always uses generation PNGs; ANIMATED uses Gen 3/5 atlases and Gen 1/2/4 PNGs |
| the **PLAYER** options row | FRONT SPRITES / BACK SPRITES — supplied art is world-placed; a missing selected back uses the ROM's UI-attached pic |
| the **BACK PLACEMENT** options row | AUTO / WORLD / OG UI — use the mode-aware default or force every player back onto one layer |
| battle HUD ink | HUD and dialogue glyphs stay white through every battle phase and receive a one-pixel dark shadow over transparent panels |
| the **DAYTIME** options row | SYNC / DAY / NIGHT / DUSK / DAWN / CYCLE — what time it is outdoors, on the diorama *and* on the flat 2D world; held at SYNC (and off the menu) while VOXEL is FULL |

**3D-BTL** is on by default and is independent of **VOXEL**: battles draw
on the world whether or not the free-roam camera is pitched over.

## Bring your own battle art

`BATTLE ART: STATIC` is the default. Drop a front PNG named for the species
into `assets/battle/front-static`, or a back PNG into the selected
`assets/battle/back-static/gen1` through `gen5` folder; for example,
`caterpie.png`, `farfetchd.png`, or `mr-mime.png`. No Lua sidecar or fixed
resolution is required, and the image is not resized. Existing alpha is
preserved. For a fully opaque PNG, the corner-coloured background connected
to the image border is keyed transparent while enclosed matching pixels are
left intact.

Enemy front art is used as authored, facing left. Player front art is mirrored
to face right; authored player back art already faces right and is not
mirrored. Every imported sprite remains a card in the 3D world, so hit flash,
depth occlusion and alpha-shaped shadows apply. Static species front
illustrations preserve their authored brightness instead of receiving the
day/night colour tint; other art continues to follow the hour. OG, inverted
and CLASSIC display filters still apply to imported art. Missing or unreadable
files fall straight back to the ROM art.

The four battle-art directories are intentionally ignored by Git except for
their README contracts. `tools/package_mod.ps1` nevertheless includes local
PNGs from them in a test ZIP, so artwork can stay private and uncommitted.
Use `tools/package_clean_mod.ps1` for a shareable install ZIP that preserves
the documented battle-art folder layout but excludes every PNG below
`assets/battle`. The clean ZIP includes the complete public `tools` folder, so
users who receive only the archive can import their own art and rebuild it
without cloning the repository. Generated Python `__pycache__`/`.pyc` files
remain excluded.
`BATTLE ART: ANIMATED` reads independent `ANIM FRONT GEN` and `BACK ART SET`
choices. GEN 1 fronts are ordinary single-frame PNGs from
`front-animated/gen1`; Gen 2–5 fronts remain animated atlases, including
converted Diamond/Pearl APNGs for GEN 4. Animated back GEN 3 and GEN 5 read
atlases from `back-animated/gen3` and `back-animated/gen5`. Back GEN 1, GEN 2
and GEN 4 read ordinary species PNGs from their `back-static` generation folders. A
loaded back is world-placed, lit, depth-occluded and shadowed. If its selected
PNG or atlas is missing or malformed, the unmodified ROM backsprite remains in
the original UI layer, including its normal battle motion and filtering.
`BACK ART SET` also appears under STATIC. In that mode every choice, including
GEN 5, reads only `back-static/<generation>/<species>.png`; it never inspects
an animated atlas. GEN 1 remains selectable when its directory is absent so
users can create it for ROM-hack art. `ANIM FRONT GEN` remains exclusive to
ANIMATED, and ROM ignores both selectors.

Run `python tools/import_emerald_back_sprites.py --root .` to import both the
animated Emerald `Spr b 3e` backs and the static `Spr b 3r` backs for the
first 151 species. The generated atlases and ordinary PNGs remain local,
ignored artwork; only their shared atlas metadata is committed.

Run `python tools/import_crystal_back_sprites.py --root .` to import the first
151 static Crystal backs. In ANIMATED mode, `BACK ART SET: GEN 1` and `GEN 2`
still select the static Yellow SGB and Crystal folders respectively; only GEN
3 and GEN 5 invoke an animated back-atlas decoder.

Run `python tools/import_platinum_back_sprites.py --root .` to populate the
static GEN 4 back set. It follows the Platinum category's mixture of `4p` and
reused `4d` files and chooses the male image for a dimorphic species.

Run `python tools/import_black_white_static_back_sprites.py --root .` to
populate static GEN 5 with the first 151 Black/White back-normal PNGs. This
does not replace or alter the animated GEN 5 atlas collection.

`BACK PLACEMENT: AUTO` keeps STATIC-mode player backs in the world, including
ROM fallbacks. Under ANIMATED, supplied Gen 1–4 PNGs and Gen 5 atlases stay in
the world while a missing selection leaves the ROM backsprite on its OG UI
anchor. ROM mode also uses OG UI. `WORLD` and `OG UI` override that decision
for testing any art set; large supplied art may crop when forced onto OG UI.

Opponent trainer cards are always static. `TRAINER ART` chooses fronts from
`front-static/gen1`, `front-static/gen2`, or `front-static/gen3`, using class
filenames such as `youngster.png`, `cooltrainer-f.png`, and
`jessie-james.png`. A missing class falls directly back to its ROM portrait;
generations are never silently mixed. In STATIC mode, `PLAYER ART` selects
player trainer backs
such as `back-static/gen1player.png`, `back-static/ashplayer.png`, or ROM.
PNG is the default and reads `back-static/player.png`; every missing named
choice tries that same generic PNG before falling back to ROM.
In ANIMATED mode, `PLAYER ANIM: PNG` reads the static
`back-static/player.png`. Named choices select the corresponding five-frame
strip from `back-animated`, while ROM retains the engine portrait. Frame one
holds during the stationary entrance pose. Frames two through five advance
once with the engine's leftward intro slide and then stop; they do not loop.
AUTO placement keeps this intro on OG UI, while WORLD and OG UI remain
explicit overrides.
Both the original five-by-64 strips and normalized five-by-80 strips are read
at native resolution. Unlike the ROM's half-resolution player back, a custom
static or animated trainer remains 1x when attached to OG UI. Use
`tools/player-animation-template-400x80.png` as the authoring guide, then
remove its coloured dividers from the finished atlas.
`back-static/oak.png` and `back-static/old-man.png` remain the scripted demo
portraits. The folder READMEs carry
the complete trainer-class list and the four exceptional Pokémon filenames.

Two of the engine's own rows are taken away while this mod is installed:
**TILT**, which is the flat fake of what this mode does for real, and **GBC
FX**, a full-screen present pass over the top of the diorama. Both are held at
off rather than merely hidden — a row that is not there cannot switch off a
value an older save arrived with. Uninstall and both come back, at whatever
they were last set to.

Everything the battle screen draws as a box — the two HUD blocks, the text
box and the menus over it — sits on frosted glass rather than on the white
field it used to have behind it: the world underneath, blurred and laid back
down translucent, with the ink flipping white where the ground it lands on is
dark. Nothing the engine draws inside a box moves; only the paper is gone.
