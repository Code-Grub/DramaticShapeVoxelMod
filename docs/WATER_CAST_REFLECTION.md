# Reflecting the cast in water

Design for a positionally accurate reflection of the player and NPCs in
water, visible at the near-overhead cameras this game is actually played at.

Implemented in `lib/Voxel3D.lua` (`beginCast`/`endCast`), `lib/VoxelScene.lua`
(`reflectPlane`, `billboardMatrix`, `drawWater`) and `lib/Water.lua` (the
`castTex` composite). Covered by `tests/water_cast_reflection_test.lua`.

## The problem

A cast reflection already exists. `VoxelScene.drawWater` passes `drawCast`
into `Voxel3D.beginWater`, which paints every character into the copy of the
frame the water reflects, and the screen-space march is supposed to find them:
a sprite is not in the depth buffer, so a ray aimed at one passes through to
the terrain behind it and reads the copy there, where the sprite is already
painted.

It does not survive contact with the ordinary camera, for two reasons.

**The horizon lean aims every ray away from anything nearby.** `Water.lean`
reaches 1 at a descent of 0.55, well before the camera reaches its steepest
rung, and at full lean a column's reflected ray is set to `LEAN_ELEV` (about
17.5 degrees) toward the horizon. That is deliberate and it is what puts sky,
sun and moon on the water at a steep camera. It also means water one tile from
a character's feet reflects the far distance rather than the person standing
beside it.

**Rays crossing water land on nothing.** With the world curve off the water
surface is never written to the depth buffer, so a low ray leaving a pier
travels out over open harbour and finds no depth to hit. It misses, and the
sky answers instead. On a pier ringed by water that is most directions.

Screen-space reflection is simply the wrong instrument for a nearby object at
a steep camera, and no tuning of it reaches the problem.

### What is not a problem

A correct mirror image is easy to see, and this is worth stating because it
was initially got backwards.

World up projects to screen up: `skyPos` maps upward directions into rows `0`
to `skyEdge`, the sky's band at the top of the frame, and every building and
tree in the scene extends upward from its base. So *lowering* an object moves
it *down* the screen, toward the viewer.

A reflection mirrored about the water plane therefore lands below the
character on screen, in front of them, in clear view. Accuracy and visibility
do not conflict, and no stylised displacement is needed to reconcile them. An
earlier draft of this design proposed one. It was solving an imaginary
problem.

## The approach

Draw the cast a second time, each card reflected in the water plane and
flipped, into a canvas of its own, and let the water shader sample it at each
fragment's own screen position. The reflection was drawn to exactly the place
a mirror would put it, so the fragment's own uv is the right place to look.
No offset to tune, no correspondence to maintain.

Masking comes free. The water shader runs on water fragments and nothing
else, so the reflection is confined to water exactly, with no stencil and no
clipping. This matters because a stencil is not available: the scene's depth
canvas prefers plain `depth24` (`lib/Voxel3D.lua:372`), so on most drivers
there is no stencil buffer at all, and reordering that list changes
allocation for the whole renderer.

### Not by mirroring the camera

The obvious implementation is to render the cast through a view-projection
premultiplied by a reflection in the plane, and reuse `drawCast` untouched.
An earlier draft of this design said exactly that. It does not work, and the
reason is worth recording because it is not obvious until it is on screen.

A character is a BILLBOARD. Its card leans back by exactly the camera's pitch
so it reads face-on. Mirror the camera and the card is caught leaning away,
so what lands in the water is a foreshortened sliver: too small, and with no
legible flip. That is the correct picture of the flat quad the card really
is, and useless as a reflection of the person it is pretending to be.

A billboard is a fake that works from one side only, so its reflection has to
be faked the same way. `billboardMatrix` reflects the POSITION, keeps the
card facing the camera, and flips it about its own feet:

- the anchor moves to `2 * plane - y`, so a card standing ON the plane is its
  own anchor and the waterline still agrees exactly
- the card's local y is negated, which hangs it downward from that anchor and
  carries its texture with it

Same lean, same size, upside down. Which is what a reflection looks like.

`reflectPlane` is ambient state for the duration of the pass rather than a
parameter threaded through the four functions between `drawWater` and the
draw, matching how `Voxel3D.glass` and `Voxel3D.seams` already switch a
pass's character. It is cleared through `pcall` so a throwing `cast()` cannot
leave the rest of the frame's cards upside down.

Authored figures are skipped in the reflection pass. A figure is not a card:
it is a mesh in its own local space placed by `Mat4.figure`, so the card flip
does not reach it, and it is a person drawn into furniture, indoors, which is
not where water is.

### The mirror plane

One plane, at the water class height. `TileShape`'s `FALLBACK_HEIGHTS` gives
`water = -2` against `ground = 0`, and it is a per-class constant that
`data/voxel_heights.lua` may override with another single number. Every water
surface in the world therefore lies in the same plane, so one height serves
the whole frame exactly rather than approximately.

The height is read from `TileShape` rather than restated, so an override
moves the reflection with the water.

### Pipeline

1. `Voxel3D.beginCast()` lazily creates `held.cast`, a full-size
   `PixelCanvas`, binds it colour-only, and clears it to transparent. No
   depth attachment: what would be tested against is the world's depth, and
   this canvas holds reflected cards that share none of it. The water
   shader's own depth test has already decided which water fragments
   survive, and a reflection only ever lands on those.
2. `VoxelScene` sets `reflectPlane` and draws the cast through the existing
   `drawCast` closure, then clears it.
3. `Voxel3D.endCast()` rebinds the scene canvas.
4. `VoxelScene.drawWater` passes the texture to `Water.begin`.
5. The water shader samples it and composites.

This runs BEFORE `beginWater`, which rebinds canvases and detaches the depth
buffer; the cast pass wants the frame intact.

The existing `drawCast` paint into the mirror copy stays as it is. It is
what the screen-space march finds at a low camera, and the two do not
conflict: one is found by rays, the other is composited in screen space.

### Sampling and compositing

In `effect()`, after the fresnel mix:

- sample `castTex` at the fragment's own screen uv, the same
  `sc / love_ScreenSize.xy` the depth test already computes, displaced by the
  wave normal's horizontal components scaled by `CAST_WOBBLE`, so the
  reflection ripples with the surface carrying it
- the canvas's alpha gates the blend, which is why it is cleared to
  transparent
- composite at `CAST_ALPHA`, **after** the fresnel mix rather than into
  `refl` before it

That last point is deliberate. Fresnel is smallest looked straight down at,
so folding the cast reflection into `refl` would fade it out at precisely the
camera this feature exists to serve.

### Rungs and fallbacks

Available at SKY as well as FULL. It is not a ray march, so it does not need
`rays`, and a device that cannot afford the march can still afford this.

Every failure degrades to current behaviour and nothing else:

- the canvas cannot be created: no cast reflection, water otherwise unchanged
- the water row is OFF, or the shader did not compile: the flat fallback, as
  today
- Android: already forced to flat water by `Water.onAndroid`, so this does
  not reach it

`held.cast` joins `releaseSlot`'s list beside `canvas`, `depth` and `mirror`,
and is created only when something asks for one, so a session that never sees
a lake never pays for it.

## Cost

- one full-size RGBA canvas per slot, allocated lazily
- one extra draw of every visible character per frame with water on screen
- one extra texture sample per water fragment

Characters nowhere near water are still drawn into the canvas, where they
land on no water fragment and are discarded. Culling to characters within
some distance of a water cell is an obvious follow-up, left out of the first
cut so the first version is measurable before it is optimised.

## Tunables

On `Water`, sent as uniforms like every other constant in that file.

| name | meaning |
| --- | --- |
| `CAST_ALPHA` | how strongly the reflection composites. |
| `CAST_WOBBLE` | how far the wave normal displaces the sample. |

There is deliberately no position or offset dial. The mirrored camera fixes
the geometry, and a knob that moved it could only make it wrong.

## Testing

- **shader compiles**, all four variants (full, full+grid, sky, sky+grid),
  through a real LOVE GLSL compile rather than by inspection. A syntax error
  here falls back to flat water silently, which is the failure mode that
  hides longest.
- **uniforms are sent.** A uniform can be declared, read, and never fed; that
  is not a compile error anywhere, and it reads as zero at runtime. Drive
  `Water.begin` with a recording shader and assert each new name arrives.
- **the mirror matrix**, which is a pure function and the part with
  arithmetic worth pinning: that a point at `y = plane` is its own image,
  that a point one unit above maps one unit below, and that x and z are
  untouched.
- **the plane is read, not restated**: overriding `TileShape`'s water height
  moves the matrix with it.
- **canvas lifecycle**: `held.cast` is released by `releaseSlot`.
- **no regressions** against the standalone suite, baselined before and after.
  `battle_art_voxel_fork_test.lua` does not compile at all (Lua's 200-local
  limit) and the two MK301 lint errors in `InterfaceSprites` are pre-existing,
  so neither is a signal.

The look itself cannot be tested here. It needs a screenshot from the same
spot each time, at a comparable time of day, because the sun's elevation
moves what the water does.

## Known limits

- **Nothing occludes the reflection.** Only the cast is rendered into the
  mirrored canvas, so a character standing behind a building still reflects
  in water in front of it. Fixing this needs terrain in the mirrored pass and
  a depth buffer to test against, which is a much larger change.
- **No depth among the characters themselves.** The cast canvas is colour
  only, so two overlapping reflections resolve by draw order rather than by
  distance. Draw order is the same one the frame uses, so this is right in
  the common case and wrong only where one character's reflection genuinely
  passes behind another's.
- **A reflection can appear on water the character could not physically see
  into**, since the water fragment tests only that the plane's image lands
  there, not that a line of sight exists.
