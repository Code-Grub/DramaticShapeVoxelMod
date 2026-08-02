# Dramatic Shape Voxel Mod

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
| `9`, or the **WATER** options row | FULL / SKY / OFF — waves and reflections on water. **SKY** gives the surface its pixel-tall wave columns and puts the sky, the sun, the moon and the cast in them; **FULL** adds a screen-space ray march that also reflects the shoreline, the trees and the buildings standing behind it |
| the **BACK SPRITES** options row | OFF / ON — keep your own Pokémon on the battle menu, seen from behind in its classic slot, instead of standing it on the map; the foe is still out there. Only on the menu while **3D-BTL** is on, because it decides nothing without it |
| the **AA** options row | OFF / 2X / 4X — smooth the stair-stepped edges of the 3D world by rendering the diorama larger than the window and folding it back down. The ladder is samples per display pixel: 2X is a canvas root-two wider and taller, 4X one exactly twice the size. Every edge in the projected picture softens with the silhouettes — the tileset's own texels are quads in a perspective view and cross the pixel grid at the same arbitrary angles — so the diorama reads smoother rather than sharper. The most expensive row in the mod, so it is OFF by default and **FULL** leaves it alone |
| the **DAYTIME** options row | SYNC / DAY / NIGHT / DUSK / DAWN / CYCLE — what time it is outdoors, on the diorama *and* on the flat 2D world; held at SYNC (and off the menu) while VOXEL is FULL |

**3D-BTL** is on by default and is independent of **VOXEL**: battles draw
on the world whether or not the free-roam camera is pitched over.

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