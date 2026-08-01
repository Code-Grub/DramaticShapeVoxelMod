# Dramatic Shape Voxel Mod

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
| the **PLAYER VIEW** options row | FRONT / BACK — choose the player's view while keeping it world-placed, lit, shadowed and depth-occluded |
| the **DAYTIME** options row | SYNC / DAY / NIGHT / DUSK / DAWN / CYCLE — what time it is outdoors, on the diorama *and* on the flat 2D world; held at SYNC (and off the menu) while VOXEL is FULL |

**3D-BTL** is on by default and is independent of **VOXEL**: battles draw
on the world whether or not the free-roam camera is pitched over.

## Bring your own battle art

`BATTLE ART: STATIC` is the default. Drop a PNG named for the species into
`assets/battle/front-static` or `assets/battle/back-static`; for example,
`caterpie.png`, `farfetchd.png`, or `mr-mime.png`. No Lua sidecar or fixed
resolution is required, and the image is not resized. Existing alpha is
preserved. For a fully opaque PNG, the corner-coloured background connected
to the image border is keyed transparent while enclosed matching pixels are
left intact.

Enemy front art is used as authored, facing left. Player front art is mirrored
to face right; authored player back art already faces right and is not
mirrored. Every imported sprite remains a card in the 3D world, so the normal
world tint, day/night lighting, hit flash, depth occlusion and alpha-shaped
shadow apply. OG, inverted and CLASSIC display filters also apply to imported
art. Missing or unreadable files fall straight back to the ROM art.

The four battle-art directories are intentionally ignored by Git except for
their README contracts. `tools/package_mod.ps1` nevertheless includes local
PNGs from them in a test ZIP, so artwork can stay private and uncommitted.
`BATTLE ART: ANIMATED` reads the PNG atlases described by
`data/animated_battle_sprites.lua`. The authoring importer generates both;
the runtime extracts native-resolution cells without a DPI-scaled canvas and
falls back per missing or malformed atlas to ROM art.

Trainer cards are always static. Opponent trainer fronts use class filenames
in `front-static` (for example `youngster.png`, `cooltrainer-f.png`, and
`jessie-james.png`). Player-side trainer backs use `back-static/player.png`,
`back-static/oak.png`, or `back-static/old-man.png`. The folder READMEs carry
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
