# Voxel Companion API v1 host integration

## Pinned sources

- Host: `BATTLE_ART_VOXEL_FORK` 1.9.7 at
  `fcbe541676cd7f245fa73df3d01dcbabec37a1fe`, dated
  2026-08-21T07:49:50+02:00.
- Host source: <https://github.com/absol89/DramaticShapeVoxelMod/commit/fcbe541676cd7f245fa73df3d01dcbabec37a1fe>
- Gen1recomp compatibility audit: commit
  `06e06e305bbcefe97c216a31bb25265ffb5e6b18`, dated
  2026-08-21T14:38:54-04:00.
- Gen1recomp source: <https://github.com/bryanthaboi/gen1recomp/commit/06e06e305bbcefe97c216a31bb25265ffb5e6b18>
- Voxel Companion API reference dispatcher: normalized SHA-256
  `7ACB41E52757898038454D2EA673AAE5AC1ED66768DBA38E4FD8104702FD569B`.

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

1. `update(frame)` runs from the voxel pipeline update. It also runs while the
   voxel display level is off, so extension compilation can finish before the
   player selects the mode.
2. `worldChanged(snapshot)` runs after a real world identity change. Multiple
   block edits before one update coalesce into one snapshot revision.
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

- `mesh` for a box, plane, and centered world apron
- `instances` for bounded prototype batches
- `billboards` for bounded camera-facing batches

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
luajit tests\voxel_companion_api_v1_test.lua
```

It covers descriptor truthfulness, canonical flat callbacks, optional
capabilities, late registration, direct world/update/camera payloads, defensive
snapshots, edit coalescing, radian camera input, graphics restoration, draw
fault isolation, deterministic continuation, disposal, legacy refusal, and the
no-write rule.

The canonical KFP dispatcher conformance command is:

```text
luajit tools\run_tests.lua companion
```

At integration time, the focused host test passed 76 checks and the canonical
KFP suite passed 32 tests. All changed Lua files also compiled with LuaJIT. The
large upstream `tests/battle_art_voxel_fork_test.lua` cannot compile as one
LuaJIT chunk because its main function already exceeds LuaJIT's 200-local
limit. This is an upstream test-harness limit, not a companion adapter failure.
