# DRAMATIC SHAPE VOXEL MOD BATTLE ART

A mod for the [Pokémon Gen 1 Recompilation
Project](https://github.com/bryanthaboi/pokemon-gen1-recomp-project).

The overworld as a 3D diorama. Terrain is extruded into real geometry,
occlusion comes from a depth buffer rather than a y-sort, characters stand
as leaning sprite slabs, a shadow map throws real cast shadows across
whatever they land on, and an optional tilt-shift pass sells the
miniature-model look.

Water is a surface rather than a texture lying in a hole. It is a field of
one-pixel-wide voxel columns, each standing a whole number of pixels tall and
rising and falling as waves — found by walking the view ray through them in
the shader, so a crest hides what is behind it and shows you its lit side,
with no extra geometry anywhere.

And it reflects. The sky it stands under, in the same bands, the same dither
and off the same clock, so the lake and the sky above it meet at the
waterline with no seam. The sun or moon hanging in it, at the size the
painted disc is drawn, craters and all. Whoever is standing beside it —
walkers, NPCs, the two Pokémon in a staged battle. And on **FULL**, a
screen-space ray march adds the rest of what is on screen: the shoreline, the
trees behind it, the buildings across the bay. How much of it shows is
Fresnel, so the top rung is a mirror and a looking-straight-down rung is a
pond, off the same water.

And battles fought on that world rather than on a white field. When
something picks a fight the map's NPCs are culled, the engine's own wipe
plays over the empty map, and the battle draws over the nearest patch of
clear ground — shot over the shoulder, the player's mon low and left and
the enemy high and right, with a slow parallax drift behind them and a
depth-of-field pass that keeps both of them sharp.

And the whole thing from inside. The ladder's top rung, **1ST**, dives the
camera into the player's own head: free look on the mouse (captured while
the rung is on — left click is A, right click is B), the right stick, or a
touch dragged across open screen; free movement that goes where you look,
at any angle, sliding along walls — the left stick's raw deflection, the
touch d-pad's true vector, or WASD as forward/backpedal/strafe. NPCs turn
to face the eye wearing the frame their pose shows *this* viewer — walk
behind someone and you see their back — and the sky, the shadows and the
water reflections all carry over, because the head rides the same placed
camera the battle shot proved out.

Presentational, with one deliberate exception. Every rung but 1ST changes
what the world *looks* like and nothing about what it *is*; the battle
arena is where the **camera** goes, not where anybody goes. 1ST replaces
the grid walk with a free one while it is selected — but even there the
game is untouched: the walk asks the engine's own collision the same
questions a grid step asks, keeps the player's cell synced, and runs the
engine's own landing pipeline per cell crossed, so warps, encounters,
ledges, gates and scripts all fire exactly as themselves. Step off the
rung and the grid walk is back.

## Game support

Battle Art 1.9.0 supports Red, Blue, and Yellow. It intentionally declares
Gen 1 only: Gold uses separate world, map, battle, script, and UI stacks, while
this mod currently integrates directly with their Gen 1 counterparts. See
[Why Battle Art is Gen 1-only today](docs/GEN1_GEN2_DIFFERENCES.md) for the
confirmed blockers, reusable renderer components, and a suggested Gen 2
porting plan.

## Controls

Every key is free-roam only, and each one is also a row on the OPTIONS
menu.

| control | does |
| --- | --- |
| `3`, or the **VOXEL** options row | OFF → 15 → 35 → 50 → 75 → 1ST → OFF (camera pitch or first-person view) |
| `5`, or the **V-GRID** options row | OFF / ON — a one-pixel wireframe on every voxel |
| `6`, or the **T-SHIFT** options row | OFF → 1 → 2 → 3 → OFF (miniature blur) |
| `7`, or the **V-CURVE** options row | OFF → 1 → 2 → 3 — bend the world over the horizon |
| `8`, or the **3D-BTL** options row | ON / OFF — fight on the map instead of on a white field |
| the **BATTLE ART** options row | STATIC / ANIMATED / ROM — use optional battle-only art, with a direct ROM fallback when a file or atlas is absent |
| the **TRAINER ART** options row | GEN 1 / GEN 2 / GEN 3 — choose a static opponent-trainer collection |
| the **PLAYER ART** options row | PNG / GEN 1–5 / ASH / GARY / BOY / LASS / HILBERT / ROM — choose the static player trainer battle-intro portrait; BATTLE ART: ROM pins it to ROM |
| the **PLAYER ANIM** options row | PNG / GEN 1–5 / ASH / GARY / RED / ASH FRONT / MISTY FRONT / BROCK FRONT / BULMA FRONT / GARY FRONT / ROM — choose a static `player.png` or five-pose player intro while ANIMATED is selected |
| the **ANIM FRONT GEN** options row | GEN 1 / GEN 2 / GEN 3 / GEN 4 / GEN 5 — choose a single-frame Gen 1 compatibility set or an animated Gen 2–5 collection |
| the **BACK ART SET** options row | GEN 1 / GEN 2 / GEN 3 / GEN 4 / GEN 5 — STATIC always uses generation PNGs; ANIMATED uses Gen 3/5 atlases and Gen 1/2/4 PNGs |
| the **DUPLICATE FIX** options row | BATTLE ART / MODDED — use the Gen 2 DV formula to route actual shinies through Battle Art's matching imported shiny collections, or leave shiny pictures to another mod/ROM; ordinary Pokémon retain their selected normal Battle Art in either mode; replaces both old SHINY FIX rows |
| the **PLAYER** options row | FRONT SPRITES / BACK SPRITES — supplied art is world-placed; a missing selected back uses the ROM's UI-attached pic |
| the **FLIP FRONT SPRITE** options row | BATTLE ART / DEFAULT — mirror ordinary Battle Art on the player side, or preserve an already-oriented picture supplied by a sprite mod |
| the **BACK PLACEMENT** options row | AUTO / WORLD / OG UI — use the mode-aware default or force every player back onto one layer |
| the **HUD COLOR** options row | COLOR keeps black HUD glyphs and coloured HP gauges with a light shadow; INVERTED uses white glyphs with a dark shadow. Gauge health remains bright green / amber / red in either mode |
| the **SHADOWS** options row | ON uses cast shadows (with the flat fallback on unsupported hardware); OFF removes both paths in free roam and staged battles. UNLIT battle sprites neither receive nor cast shadows even while this is ON |
| `9`, or the **WATER** options row | FULL / SKY / OFF — waves and reflections on water. **SKY** gives the surface its pixel-tall wave columns and puts the sky, the sun, the moon and the cast in them; **FULL** adds a screen-space ray march that also reflects the shoreline, the trees and the buildings standing behind it |
| the **AA** options row | OFF / 2X / 4X — smooth the stair-stepped edges of the 3D world by rendering the diorama larger than the window and folding it back down. The ladder is samples per display pixel: 2X is a canvas root-two wider and taller, 4X one exactly twice the size. Every edge in the projected picture softens with the silhouettes — the tileset's own texels are quads in a perspective view and cross the pixel grid at the same arbitrary angles — so the diorama reads smoother rather than sharper. The most expensive row in the mod, so it is OFF by default and **FULL** leaves it alone |
| the **DAYTIME** options row | SYNC / DAY / NIGHT / DUSK / DAWN / CYCLE — what time it is outdoors, on the diorama *and* on the flat 2D world; held at SYNC (and off the menu) while VOXEL is FULL |

Fresh installs start at **VOXEL: FULL**, with **PLAYER: BACK SPRITES** and the
other defaults listed above. Existing saved choices, including VOXEL: OFF,
are preserved across updates.

**3D-BTL** is on by default and is independent of **VOXEL**: battles draw
on the world whether or not the free-roam camera is pitched over.

## Persistent voxel precache

Persistent mesh precaching is available on legacy engines that expose the
filesystem and FFI facilities it needs. Current sandboxed engines hide the
PRECACHE and CACHE actions; they build meshes through bounded packed buffers
in session memory instead, with **R.DIST: MEDIUM** limiting adjacent-map work.

The title menu's **PRECACHE** item opens **GENERATE PRECACHE** before gameplay.
It cooperatively prepares every persistent mesh variant the renderer can ask
for, shows live progress and disk use, and remains cancellable with B. Running
it again resumes: records whose exact input fingerprint is still valid are
counted as EXISTING rather than rebuilt.

The generator writes only beneath
`mod-derived/BATTLE_ART_VOXEL_FORK/static-mesh-cache-v2` in the game's save
directory. At `mods.loaded` it takes a private snapshot of the final map and
tileset geometry, after content mods have patched it but before gameplay can
change it:

- one `MAP.full.terrain.bavc` for every loadable map, containing terrain and
  the separately drawn water surface, with that map's connection masks;
- one `MAP.body.terrain.bavc` only for maps participating in seamless outdoor
  connections, because only neighbour rendering requests the body-only form;
- one shared `MAP.aux.bavc` per generated map, containing tall grass, flowers,
  and authored figure geometry.

These records contain only geometry derived from that immutable snapshot:
terrain, water sheets, buildings, trees, static grass/flowers and figures
authored into the tileset. Runtime NPCs and spawned overworld Pokemon remain
ordinary sprite billboards and never enter a disk record or fingerprint. If a
script, Cut or a door changes a live block, that one live map is meshed in RAM;
it neither reads nor replaces the canonical static file. Returning to the
canonical layout reuses the disk mesh again.

For auditing, the mod builds
`mod-derived/BATTLE_ART_VOXEL_FORK/static-cache-exclusions.tsv`. It records the
map, component and asset key for runtime objects and noncanonical live geometry
which were deliberately refused by background/persistent precaching. It is a
human-readable exclusion ledger, not a permanent map blacklist: a spawned
Pokemon can never poison its town's canonical terrain cache.

BAVC is a small documented container, not a serialized GPU object or ROM dump:
a `BAVC`/version/fingerprint header followed by LZ4 chunks of interleaved
`position.xyz`, `uv.xy`, `shade` float vertices. Standard GLB was evaluated for
inspectability, but the measured 744 MiB test cache contains 2.73 GiB of raw
vertex data; without shipping a mesh-compression decoder, GLB would increase
mobile storage about 3.7 times. Corrupt/truncated records fail open to the
ordinary cooperative mesher. Runtime meshes are released between maps, so
generating the whole cache does not hold the whole world in RAM.

The completion screen reports map, file, FULL/BODY/AUX counts and total MiB or
GiB. Exact size depends on the imported ROM and installed map/tileset content;
large routes dominate and a complete cache can occupy hundreds of MiB or more.
The directory is disposable: deleting it only makes the mod regenerate static
meshes. The older `mesh-cache-v1` directory is no longer read and may be removed
manually after confirming the v2 build.

## Battle UI compatibility

Battle Art automatically yields its native battle HUD, text/menu layer and
panels to the installed `gen3_battle_ui` while that mod's `revampedBattleUI`
option is enabled. Mimic, Safari and the scripted demo retain native text
because Gen 3 UI v0.1 does not replace those phases.
The older `gen1_modern_ui` adapter is also recognised when its experimental
`battleUiWip` option is explicitly enabled.

Other replacement presenters can wrap
`battle.presentation.suppress_native.v1`. The request reports API version 1,
source ID `BATTLE_ART_VOXEL_FORK`, the requested `hud`, `text`, or `panels`
surface, and the current battle when available. Return exactly `true` only
when the consumer will draw that complete surface. The descriptor is exported
as `mod.find("BATTLE_ART_VOXEL_FORK").exports.battlePresentation`; absent,
throwing or false consumers fail open to Battle Art's native presentation.

### Staged-battle compatibility API

Effects and presentation mods can read the versioned, read-only descriptor at
`mod.find("BATTLE_ART_VOXEL_FORK").exports.battleStage`. Its `state(battle)`
function returns `nil` unless that exact battle is staged. A staged session is
reported immediately with `staged=true`; `ready` becomes true once the first
projected shot exists.

Ready state includes copied authored and projected player/enemy anchors,
back-sprite pinning, the animation scale and complete layer transform. It also
declares Battle Art's arena, battler, trainer, camera, HUD, transition and
animation-projection ownership. Consumers can therefore align their effects
or yield competing presentation without importing Battle Art's internal
modules, retaining live tables, or changing either mod's settings. API version
1 is observational only.

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
such as `back-static/gen1player.png`, `back-static/ashplayer.png`,
`back-static/boyplayer.png`, `back-static/lassplayer.png`,
`back-static/hilbertplayer.png`, or ROM.
PNG is the default and reads `back-static/player.png`; every missing named
choice tries that same generic PNG before falling back to ROM.
In ANIMATED mode, `PLAYER ANIM: PNG` reads the static
`back-static/player.png`. Named choices select the corresponding five-frame
strip from `back-animated`; the five `*frontplayer.png` choices retain their
authored front-facing poses, while ROM retains the engine portrait. Frame one
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

The two battle HUD blocks sit on frosted glass over the world. `TEXTBOX FILL`
controls the engine's own text and menu paper independently: WHITE (the
default), translucent HALF, opaque BLACK, or OFF. Dark and transparent modes
use white ink with a one-pixel shadow, while `ARENA FILL: WHITE` forces the
guaranteed-readable white box. The engine still owns the box geometry, so its
border, corners and ink remain aligned under both fixed and fill scaling.
`HUD COLOR: COLOR` (the default) keeps black names, levels and HP text with
the original green/yellow/red bars and a bright one-pixel shadow. INVERTED
uses white HUD ink with a dark shadow. The setting affects only the opponent
and player status blocks, never textbox ink; `ARENA FILL: WHITE` forces COLOR.
