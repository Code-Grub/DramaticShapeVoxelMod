# Why Battle Art is Gen 1-only today

Battle Art 1.9.0 supports the Gen 1 games: Red, Blue, and Yellow. The manifest
deliberately declares `"games": ["gen1"]`, so a Gen 2 game skips the mod rather
than starting a renderer whose engine integrations were written for Kanto.

This is not an asset limitation. Much of the artwork, GPU renderer, camera
math, and image handling can be reused for Gold. The present limitation is the
code between those reusable pieces and the game: Gen1Recomp has distinct Gen 1
and Gen 2 world, battle, script, and UI implementations. Battle Art currently
patches or reads many Gen 1 implementation details directly.

Simply adding `"gen2"` to the manifest would therefore be unsafe. Some hooks
would never run, some would refer to the wrong screen or data shape, and at
least one module would fail during startup.

The engine developers' companion document is the
[Guide: Preparing Your Mod For Gen 2](https://github.com/bryanthaboi/gen1recomp/wiki/Guide-Preparing-Your-Mod-For-Gen-2).

## Confirmed blockers

The engine's `modkit gen2check` currently reports these concrete issues:

- `lib/MomHealFlash.lua` imports `src.script.Commands` and replaces the Gen 1
  `fade` command. Gold does not run that module, and the compatibility layer
  has no adapter for it. This is a startup blocker if Gen 2 is enabled without
  first making the installation game-specific.
- `StartMenu` is used as a literal screen id in `lib/FreeMove.lua` and
  `main.lua`. Gold uses `Gen2StartMenu`, so these paths would open or compare
  the wrong screen.
- The manifest currently names only `gen1`. This is intentional containment,
  not the underlying technical cause.

The audit cannot prove that every `engine_internals` member is portable. A
missing error in that report does not mean the remaining integrations already
work on Gold.

## Important architectural differences

### World and map data

The voxel scene reads Gen 1 `src.world.Map`, `MapLoader`, tileset definitions,
block layouts, border blocks, seamless connections, and live `Map:setBlock`
updates. Terrain classification, authored structures, water, flowers, grass,
indoor voids, and persistent mesh fingerprints all begin with those shapes.

Gen 2 has a separate world/map stack and different generated data. A port
needs a translator that presents Gold maps to the mesher in a stable neutral
shape. Pointing the existing code at a Gen 2 map table is not sufficient.

### Player, NPCs, collision, and first-person movement

Free movement currently wraps Gen 1 `OverworldController:handleInput` and asks
Gen 1 `Collision` and field-data tables about occupancy, ledges, warps, forced
movement, cycling, surfing, encounters, and step completion. Character cards
also assume Gen 1 player, NPC, and follower records.

Gold has different world objects and movement/script ownership. The visual
first-person camera is reusable, but walking must call Gold's own movement and
landing consequences. Reusing the Gen 1 movement wrapper would risk skipped
warps, events, encounters, or scene scripts.

### Battles

Staged battles currently wrap Gen 1 `src.battle.BattleState` and Gen 1
`OverworldController:pushBattle`. Battle Art reads and replaces Gen 1 picture
layers, HUD layers, placement helpers, Transform effects, trainer constructors,
and battle lifecycle methods.

Gold has a separate Gen 2 battle engine and Gen 2 battle UI. The arena camera,
depth-of-field pass, backplates, imported sprite assets, and projection math
remain useful, but a new battle adapter must provide:

- battle start and end notifications;
- player and opponent monster records;
- front/back image ownership and placement;
- trainer and wild encounter identity;
- Transform state;
- HUD, text, animation, and picture-layer suppression seams.

### Scripts and field effects

Two small presentation fixes patch Gen 1 gameplay classes directly:

- Mom's heal-flash suppression replaces `src.script.Commands.fade` and checks
  for `REDS_HOUSE_1F`.
- Poison-flash suppression replaces Gen 1
  `OverworldController:applyFieldPoison`.

These fixes must be installed only for Gen 1. Gold's mom, healing sequence,
field poison behavior, and script VM should remain untouched unless a separate
Gen 2-specific presentation fix is designed and tested.

### Menus and screen ids

Options, party, box, start-menu, and battle UI hooks currently target Gen 1
classes and screen ids. Gold has Gen 2 screens and layouts. A port should use
generation-neutral engine hooks where available and separate adapters where
the screen implementations genuinely differ.

### Location-specific content

The GEN6 arena router contains Kanto map ids and encounter rules. The image
loader and time-of-day snapshot are reusable, but Gold needs a Johto/Kanto
Gen 2 mapping table. Unmatched locations should continue to fall back safely
instead of borrowing an unrelated Kanto picture.

## Reusable portions

The following parts are good foundations for a Gen 2 port.

### Reusable as-is or with very small changes

- `Mat4` and the low-level camera/projection math.
- `Voxel3D` GPU resources, shaders, depth rendering, canvas handling, and
  backdrop compositing.
- Packed mesh upload in `ChunkMesher`, once supplied neutral geometry.
- Anti-aliasing, depth of field, voxel grid, world curve, and most
  post-processing code.
- `BackdropImage` loading and cover-fit behavior.
- Mod settings, `input.pointer`, source-owned `mod.input`, and controller
  input handling.
- Render-distance rectangle math.
- Static and animated Battle Art image collections.

### Reusable algorithms that need a Gen 2 adapter

- Terrain and structure meshing. The algorithms are reusable after Gen 2
  blocks, tiles, palettes, and borders are translated.
- Water, sky, day/night tint, shadows, and reflections. These need Gold map
  outdoor/canopy/water metadata and its current time-of-day source.
- First- and third-person cameras. Camera placement is reusable; player and
  character extraction plus movement are not.
- Staged-battle arena search and camera composition. They need Gold collision,
  map, battle, sprite, and lifecycle adapters.
- Shiny routing. Gen 2's DV shiny predicate is already owned by Battle Art and
  is conceptually appropriate, but the DVs and active species must be read
  from Gold's monster and Transform records.
- GEN6 backgrounds and boss selection. The selection framework is reusable;
  the location/encounter mapping needs Johto data.

### Gen 1-specific code to replace or conditionally skip

- `MomHealFlash` and `PoisonFlash` installation.
- Direct `src.script.Commands`, Gen 1 `BattleState`, `OverworldController`,
  `Map`, `Collision`, and Gen 1 menu-class modifications.
- Literal Kanto screen and map ids where they represent engine behavior rather
  than optional content mappings.
- Gen 1 field-data assumptions in free movement and mesh invalidation.

## Suggested porting sequence

1. Keep the manifest Gen 1-only while building the port. Add an explicit game
   discriminator at startup and conditionally install every direct Gen 1
   patch, beginning with Mom/poison flash and menu hooks.
2. Define a small neutral world adapter: map id, dimensions, outdoor status,
   tileset/palette, blocks, connections, player position, characters, and live
   geometry invalidation.
3. Implement that adapter for Gen 2 and render a stationary Gold map with
   first-person movement and staged battles disabled.
4. Adapt characters, water metadata, day/night, shadows, and connected maps.
5. Integrate Gold movement through its own collision and step/event APIs. Test
   warps, ledges, encounters, forced movement, followers, and scripted scenes
   before enabling 1ST.
6. Build a Gen 2 battle adapter. Start with static front/back art and ordinary
   wild battles, then trainers, Transform, animation, HUD suppression, fishing,
   surfing, and special encounters.
7. Add Johto background mappings and Gen 2 menu/UI integrations.
8. Run `modkit gen2check`, engine fixture tests, and real Gold playtests. Only
   then add Gen 2 to `manifest.json`.

## Definition of ready

Gen 2 should not be advertised merely because the mod boots. A supported build
should at minimum pass:

- outdoor, indoor, cave, water, and connected-map rendering;
- map edits and revisits without stale geometry;
- ordinary walking plus first-person collision, warps, encounters, and scenes;
- wild, trainer, fishing, surfing, shiny, and Transform battles;
- party/box/menu entry and exit without Gen 1 screen assumptions;
- Mom healing and poison behavior without modifying gameplay;
- clean fallback when optional art is missing;
- both legacy and sandboxed engine mesh paths where applicable.

Until those conditions are met, the Gen 1-only manifest is a safety feature:
Gold gets the engine's native renderer instead of a partially installed mod.
