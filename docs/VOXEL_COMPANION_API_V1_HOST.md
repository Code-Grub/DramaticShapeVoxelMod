# Voxel Companion API v1 host integration

## Pinned sources

- Host: `BATTLE_ART_VOXEL_FORK` 1.9.7 at
  `fcbe541676cd7f245fa73df3d01dcbabec37a1fe`, dated
  2026-08-21T07:49:50+02:00.
- Host source: <https://github.com/absol89/DramaticShapeVoxelMod/commit/fcbe541676cd7f245fa73df3d01dcbabec37a1fe>
- Gen1recomp stable audit: v0.2.18 commit
  `70d7b6383e2c005857013dc897fd096886b08f0b`, dated
  2026-08-21T17:10:00-04:00.
- Stable source: <https://github.com/bryanthaboi/gen1recomp/commit/70d7b6383e2c005857013dc897fd096886b08f0b>
- Gen1recomp development audit: commit
  `087a2751895899ad6e79800599ae27a8f40cf1e3`, dated
  2026-08-21T16:36:55-04:00.
- Development source: <https://github.com/bryanthaboi/gen1recomp/commit/087a2751895899ad6e79800599ae27a8f40cf1e3>
- Frozen Voxel Companion API reference dispatcher: byte-exact SHA-256
  `6FDED9C804298AB064DB61B908382BE7C9A74AD29D611444C33E1BCC53A33D26`.

The integration does not change the upstream mod identifier, manifest version,
load priority, permissions, conflicts, or package layout. The existing package
scripts include all files under `lib`, so they include the adapter and vendored
dispatcher without a packaging rule change.

## Honest capability descriptor

The exported `mod.exports.voxel_companion` provider advertises only these v1
capabilities:

- `world_snapshot`
- `camera_delta`
- `render_phases`
- `quality_tier`
- `integrity_status`

It does not advertise `terrain_patch`, `shadow_pass`, or `battle_pass`. It also
does not advertise `materials` or `draw`; those names are borrowed facades, not
wire capabilities. A descriptor that supplies `shadow_casters` or
`battle_opaque` is refused because this host does not run companion work in
those passes.

## Host seams

The adapter uses only existing host-owned seams:

1. The public `core.update` hook runs the engine update first, then observes
   `game.overworld` and sends `update(frame)`. It also runs while the voxel
   display level is off, so extension compilation can finish before the player
   selects the mode.
2. Startup can have no map. The adapter keeps one snapshot pending and sends
   `worldChanged(snapshot)` when the real overworld becomes ready. Later map
   identities and coalesced block edits send one newer revision.
3. `modifyCamera(camera)` runs after the first-person rig is built and before
   projection. The host applies finite additive values only. Position is
   limited to 32 world units per axis, rotation to 0.5 radians per axis, and
   FOV to the host range of 20 to 120 degrees. API input remains radians.
4. `background` runs after the host opens its 3D scene and before terrain.
5. `opaque_after_terrain` runs after host terrain and distant fill props and
   before water and actors.
6. `translucent_after_actors` runs after host actors, water, grass, and flowers
   and before the scene resolves.

The adapter does not enter `ShadowMap` or `BattleScene`. It does not suppress,
replace, or mutate base terrain.

## World snapshot

The snapshot is copied from the current Gen1recomp overworld and map APIs. It
contains the game identity, map and tileset revisions, display mode, map tags,
player pose, bounded actor and neighbor lists, and normalized cells. Cell tags
come from the host tile shape plus Gen1recomp walk, water, grass, and warp
queries.

Hard limits are:

- 262,144 cells
- 2,048 actors
- 8 neighbors

The public facade returns defensive plain-data copies. Snapshot construction is
protected by one outer fault boundary. It does not use a protected call for
each cell query. This keeps map-change work bounded without adding several
protected calls per cell. Player movement does not rebuild the full map.

## Draw adapter and safety

The draw facade implements the three v1 draw methods:

- `mesh` for box, plane, centered world apron, panorama, cloud layer, and
  rainbow geometry
- `instances` for bounded batches of box, plane, door frame, window, poster,
  rail, fixture, sconce, cave roof, grass clump, canopy, vine, umbrella,
  mountain, and hood prototypes
- `billboards` for bounded explicit camera-facing items and deterministic
  procedural stars

Extensions call each method with the canonical dot-call form
`draw.<kind>(command, context)`. A draw returns exactly `true` when the host
accepts it. A rejection returns `false, error`; it does not throw across the
facade boundary. Every command must use `schemaVersion = 1` and a 1 to 64 byte
cache key made only from `[A-Za-z0-9._:-]`. This generic host rule does not
require a producer prefix. KFP-produced commands use the stricter profile
`kfp1:<scene8>:<generation>:<phaseId>:<sequence>:<content16>`.

For KFP instances, `cutaway = true` applies the declared interior intent in
first-person, third-person, and diorama modes. The adapter omits nearby
`role = "ceiling"` items within four cells of the player. For `role = "wall"`,
it omits only the nearby shell between the public camera eye and player; far
and side walls remain as a readable room cross-section. If the public eye is
unavailable, the wall remains. `primitive = "canopy"` uses the same inclusive
radius only in first person. Released canopy packets without explicit cell
coordinates remain compatible: the adapter derives their cell from normalized
cell-center positions and the defensive world snapshot's `cellSize`. Other
missing player or item coordinates fail open and keep the geometry visible.
`cutaway = false`, items outside the radius, and other roles remain visible.
The adapter does not retain the frame-local camera context.

The adapter copies each accepted cache key and stores an independent bounded
digest of declarative command content. Reuse with the same content is valid.
Reuse with different content fails closed. The registry holds at most 4,096
entries and is cleared on invalidation. It does not retain commands, nested
command tables, texture handles, or derived command geometry.

`command.texture` is an optional opaque resource borrowed only for the active
draw callback. A string path is refused. The adapter can pass the borrowed
texture to `Voxel3D.draw`, then unbinds it before returning. It never stores,
releases, or substitutes ownership of that texture. The shared validator also
refuses a direct opaque `command.mesh` or `command.resource` combined with a
texture. That unsafe combination would require the host to mutate one borrowed
resource to attach another.

Panorama uses a fixed 32-segment host-owned cylinder and its callback-borrowed
texture. The physical cylinder keeps the released radius of 900 world units,
top at 300, normal bottom at -120, and deep-skirt bottom at -1400.
`sourceWidth` and `targetWidth` are texture quality metadata and never scale
world geometry. The authored texture spans only -120 through 300. A separate
deep-skirt ring samples its bottom texture row from -1400 through -120, so the
painted skyline is never stretched into the closure. Distance haze changes RGB
only; texture alpha stays the only coverage source, which avoids the host
shader's ordered-alpha bands.

Cloud layers require a callback-borrowed KFP texture and use one fixed closed
32-by-16 host shell with a maximum 192-world-unit horizontal diameter and a
maximum 736-world-unit vertical diameter. The shell remains centered on and
strictly encloses the public camera eye; its upper pole retains the high cloud
deck position and its lower half closes below the world. Every geometric edge
has two faces, so opaque mask pixels have no mesh perimeter at which to clip.
Shared vertices and planar X/Z UV projection also remove longitude seams and
detached facets. Material coverage is opaque and depth writes remain off. A
missing texture fails closed at the shared validator. The adapter unbinds a
cloud texture after each draw and never retains or releases it. If unbinding
fails, it evicts and releases only the host-owned mesh before it reports the
failed draw. This keeps the layers high and non-occluding without the former
screen-covering translucent fallback planes. Rainbow uses one fixed
24-segment ribbon.
Required declarative fields select bounded transforms, density, parallax, and
deterministic placement. These are conservative API baseline visuals. They do
not claim rich parity with KFP 1.x sky art or weather.

Procedural stars expand to at most 2,048 temporary camera-facing items with a
local Park-Miller stream. The stream is seeded only from the command. It does
not call or reseed the global random generator. Generated items and resource
handles are not retained.

One phase accepts at most 2,048 items per packet and 4,096 draws per frame.
Geometry positions and primitive sizes are finite and limited to 65,536 host
world units at the adapter boundary.
Unsupported mesh primitives fail only the requesting extension. The host base
scene continues.

Every companion render phase uses `love.graphics.push("all")` and a matching
`pop`. The adapter also restores the host `Voxel3D.glass` shader selector after
each draw, including a failed draw. The reference dispatcher isolates callback
faults, records a bounded diagnostic, disposes the failed extension once, and
continues later extensions in deterministic order.

The dispatcher never calls conversion callbacks while it labels an untrusted
table key. It copies validated flat lifecycle callback references during
registration. Later descriptor changes cannot replace cleanup behavior.
Validation failures always clear dispatch state, so a bad callback payload does
not block the next frame. Camera merging is transactional: if finite inputs
would make an aggregate non-finite, only that contribution is faulted and later
extensions continue from the last finite aggregate. The dispatcher keeps its
reentrancy guard active through fault cleanup. A failed extension's cleanup
cannot reenter dispatch, register another extension, or dispose the dispatcher.

The adapter does not replace a global LÖVE callback. It does not retain borrowed
callback contexts or service leases. Disposal releases adapter GPU resources
and drops world and activation references.

## Legacy splice refusal

The adapter reads only known upstream host targets. It scans for exact literals
written by the old KFP patcher in:

- `main.lua`
- `lib/VoxelScene.lua`
- `lib/FirstPerson.lua`
- `lib/Structures.lua`
- `lib/ChunkMesher.lua`
- `lib/Ceiling.lua`
- `lib/Backdrop.lua`
- `lib/SkyLayer.lua`
- `lib/Flora.lua`
- `lib/Jump.lua`

If a marker is present, `register` returns a diagnostic that names the first
contaminated target and tells the user to reinstall a clean voxel host. The
scan and refusal do not write, restore, remove, or rename any file.

## Verification

Run the focused host test from the repository root:

```text
luajit tests\companion_lifecycle_test.lua
luajit tests\voxel_companion_api_v1_test.lua
```

They cover delayed overworld readiness through the public core hook, descriptor
truthfulness, canonical flat callbacks, callback snapshots,
optional capabilities, late registration, guarded hot attach, hot start, and
handle-invalidate fault cleanup, direct world/update/camera payloads,
transactional finite camera aggregation, defensive snapshots, edit coalescing,
radian camera input, graphics restoration, exact draw results, generic safe
keys, untrusted-key formatting, KFP producer keys, schema rejection, unsafe
direct-resource texture refusal, borrowed panorama and cloud texture ownership,
detach-failure mesh eviction, closed-manifold cloud geometry, camera
containment, transformed cloud bounds, missing-cloud-texture refusal,
key-content collision refusal, all shared baseline
primitives, producer-declared ceiling intent in every camera mode,
far-shell-preserving wall cross-sections, first-person-only canopy cutaways,
cutaway radius boundaries, fail-open cell metadata, draw fault isolation,
dispatch recovery, deterministic continuation, disposal, legacy refusal, and
the no-write rule.

The canonical KFP dispatcher conformance command is:

```text
luajit tools\run_tests.lua companion
```

At integration time, the lifecycle test passed 11 checks, the focused host
test passed 2,610 checks, the canonical
companion selector passed 54 tests, and the complete KFP suite passed 227
tests. The complete 23-command ROM-free draw fixture has canonical LF SHA-256
`DE1DCA98A04AD9446B0AF4C13523DAB7F365BC7A76E70BC44B24F323D98A9BFA`.
All changed Lua files also compiled with LuaJIT. The large upstream
`tests/battle_art_voxel_fork_test.lua` cannot compile as one LuaJIT chunk
because its main function already exceeds LuaJIT's 200-local limit. This is an
upstream test-harness limit, not a companion adapter failure.
