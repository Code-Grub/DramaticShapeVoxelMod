-- The Pokemon Center heal overlay, placed against the machine it belongs to.
--
-- The engine draws the monitor tile and the party's Poke Balls
-- (PokeCenterOAMData) as ordinary 2D sprites at fixed screen offsets from
-- the cell the player healed on, and ctx.drawFx slides that whole block
-- rigidly onto ONE projected point -- the player's own feet
-- (OverworldController's `at(fxHeal, healAnim.px + 8, healAnim.py + 16)`).
-- The art it paints belongs about 60 world pixels north of there, on a
-- machine 17 voxels tall, so under a perspective camera the block floats off
-- the cabinet: measured against the machine's real surfaces it rides ~9px
-- high at the 35 degree rung and ~14px at 50, and the monitor and the balls
-- drift by different amounts, so no single offset can seat them both.
--
-- HealOverlay answers with world points instead of a screen slide: every
-- piece is placed on the SURFACE the drawing extrudes it onto, so the same
-- projection that draws the rest of the scene puts it there too.
--
-- These checks are pinned to data/voxel_heights.lua's own machine template
-- rather than to copied numbers -- if the cabinet's depth, its height or the
-- console's inset move, the overlay has to move with them.
--
--   luajit mods/BattleArtVoxelFork/tests/heal_overlay_test.lua

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")
local MOD_PATH = os.getenv("DS_MOD_PATH") or "mods/BattleArtVoxelFork"
local ROOT = os.getenv("DS_REPO_ROOT") or "."
local base = ROOT .. "/" .. MOD_PATH
local modules, dataFiles = {}, {}
local V = {}
function V.require(name)
  if modules[name] ~= nil then return modules[name] end
  local value = assert(loadfile(base .. "/lib/" .. name .. ".lua"))(V)
  modules[name] = value
  return value
end
function V.data(name)
  if dataFiles[name] ~= nil then return dataFiles[name] end
  local value = assert(loadfile(base .. "/data/" .. name .. ".lua"))(V)
  dataFiles[name] = value
  return value
end

local HealOverlay = V.require("HealOverlay")

-- ------- the machine, as the mod actually voxelizes it

local function template(id)
  for _, t in ipairs(V.data("voxel_heights").buildings.POKECENTER) do
    if t.id == id then return t end
  end
end

local machine = template("center_heal_machine_w")
T.check(machine ~= nil,
  "the POKECENTER catalogue still carries center_heal_machine_w")

-- Buildings.deskSetModel's own arithmetic, restated: the cabinet's height is
-- its drawn base band plus its fascia, its box runs `depthPx` back from `z`,
-- and the console stands on the lid, `depth` deep from its own `z`.
local plane = (machine.desk.base[2] - machine.desk.base[1] + 1)
            + (machine.desk.fascia[2] - machine.desk.fascia[1] + 1)
local frontZ = machine.desk.z + machine.desk.depthPx      -- cabinet front plane
local console
for _, p in ipairs(machine.parts) do
  if p.kind == "upright" and p.inset then console = p end
end
local consoleZ = console.z + console.depth                -- console front plane
local groundRow = machine.desk.base[2]                    -- drawn row of the floor

T.eq(plane, 17, "the heal machine cabinet is 17 voxels tall")
T.eq(frontZ, 26, "its front face is the z=26 plane of the plot")
T.eq(consoleZ, 24, "the console's face stands 2px behind the cabinet's")

-- ------- the plot, found from the cell the player healed on

local ha = { px = 48, py = 48, balls = 3, lit = 3, visible = true }
local px0, py0 = HealOverlay.plot(ha)
T.eq(px0, 16, "the west machine's plot begins at world x 16")
T.eq(py0, 0, "...and at world y 0, the back row of the Center")

-- The plot origin is not a guess: the engine paints the monitor tile at flat
-- world (px - 20, py - 44), and the template puts that tile's lit rectangle
-- exactly on the console inset the drawing cuts at grid x 13..18.
T.eq(px0 + console.inset.x[1], ha.px - 20 + 1,
  "the monitor tile's lit rectangle starts on the console inset's first column")
T.eq(px0 + console.inset.x[2], ha.px - 20 + 6,
  "...and ends on its last")

-- ------- where each piece goes

local pieces = HealOverlay.points(ha)
local monitor, balls = nil, {}
for _, p in ipairs(pieces) do
  if p.kind == "monitor" then monitor = p else balls[#balls + 1] = p end
end

T.check(monitor ~= nil, "the overlay places the monitor")
T.eq(#balls, 3, "one ball per healed party member, and no more")

-- the monitor rides the console's face, centred on the inset the drawing cuts
if monitor then
  T.eq(monitor.z, py0 + consoleZ, "the monitor sits on the console's front face")
  T.eq(monitor.x, px0 + (console.inset.x[1] + console.inset.x[2] + 1) / 2,
    "...centred across the inset's columns")
  -- the front elevation extrudes drawn row r to height groundRow - r, which
  -- is what puts the fascia's first row at the lid and the base's last on
  -- the floor; the inset band is that same mapping over its own rows
  local top = groundRow - console.inset.rows[1]
  local bottom = groundRow - (console.inset.rows[2] + 1)
  T.check(monitor.h > bottom and monitor.h < top,
    ("the monitor's height lands inside the inset band %d..%d (got %s)")
      :format(bottom, top, tostring(monitor.h)))
  T.check(monitor.h > plane,
    "...which is above the cabinet lid, where the console actually stands")
end

-- the balls ride the cabinet's front panel, in the two columns the fascia
-- notches, and every one of them is ON the cabinet: no floor, no ceiling
local seenX = {}
for i, b in ipairs(balls) do
  T.eq(b.z, py0 + frontZ, ("ball %d sits on the cabinet's front panel"):format(i))
  T.check(b.x > px0 + machine.desk.x[1] and b.x < px0 + machine.desk.x[2] + 1,
    ("ball %d stands within the cabinet's own columns (got %s)")
      :format(i, tostring(b.x)))
  T.check(b.h > 0 and b.h <= plane,
    ("ball %d is on the panel, not through the floor or the lid (got %s)")
      :format(i, tostring(b.h)))
  seenX[b.x] = true
end
local columns = 0
for _ in pairs(seenX) do columns = columns + 1 end
T.eq(columns, 2, "the balls fill two mirrored columns")

-- and the flip survives: the right column is the left one's OAM_XFLIP
local flipped = 0
for _, b in ipairs(balls) do if b.flip then flipped = flipped + 1 end end
T.eq(flipped, 1, "with three balls lit, exactly one of them is the flipped column")

-- ------- the regression this exists to hold
--
-- Unaided, ctx.drawFx treats the whole overlay as flat art lying on the
-- ground plane at its drawn row (main.lua's `Voxel3D.project(wx, 0, wy)`).
-- Both of those are wrong here by a whole machine.
if monitor then
  local flatY = ha.py - 64 + 20 + 3.5     -- the lit rectangle's centre, flat
  T.check(monitor.h > plane,
    "the monitor is lifted onto the console instead of lying on the floor")
  T.check(monitor.z - flatY > 8,
    ("the monitor is set back onto the machine's face rather than left at its "
     .. "drawn row (face %s, drawn %s)")
      :format(tostring(monitor.z), tostring(flatY)))
end

-- ------- and how big it draws, which is a separate question
--
-- The orbit frames exactly `vh` world pixels, so the flat renderer's own
-- scale is very nearly right there.  1ST and 3RD ride a placed camera whose
-- framing comes from its fov and how far the eye stands, and a world pixel
-- draws about 3.8x and 1.45x bigger than that scale respectively -- which is
-- what shrank the balls and the monitor to a quarter and two thirds size on
-- those rungs.  `place` measures the size off the projection instead, so
-- these run it against projections that stand in for each case.

local target = HealOverlay.points(ha)[2]      -- a ball on the front panel

-- a camera that magnifies the world k times, whatever the flat scale says
local function magnify(k)
  return function(x, h) return x * k, (100 - h) * k end
end

local sx, sy, s = HealOverlay.place(magnify(4), target, 1)
T.eq(sx, target.x * 4, "the piece lands where the projection puts it")
T.eq(sy, (100 - target.h) * 4, "...on both axes")
T.eq(s, 4, "a world pixel is measured off the projection, not taken from the "
        .. "flat renderer's scale (the 1ST/3RD shrink)")
T.eq(select(3, HealOverlay.place(magnify(1), target, 1)), 1,
  "and a camera that agrees with the flat scale is left alone")

-- seen along the machine, the east step collapses but the up step does not
local function edgeOn(k)
  return function(x, h, z) return z * k, (100 - h) * k end
end
T.eq(select(3, HealOverlay.place(edgeOn(5), target, 1)), 5,
  "an edge-on view sizes off the up step rather than shrinking to nothing")

-- a projection with nothing to say about the neighbours still has to draw
local function centreOnly(p)
  return function(x, h)
    if x == p.x and h == p.h then return 10, 20 end
    return nil
  end
end
local cx, cy, cs = HealOverlay.place(centreOnly(target), target, 7)
T.eq(cx, 10, "a centre-only projection still places the piece")
T.eq(cs, 7, "...and falls back to the flat scale for its size")

T.eq(HealOverlay.place(function() return nil end, target, 1), nil,
  "a piece behind the camera is not drawn at all")

-- lit balls track the party, and nothing is drawn before the first one lights
T.eq(#HealOverlay.points({ px = 48, py = 48, balls = 6, lit = 0 }), 1,
  "before any ball lights, only the monitor is drawn")
T.eq(#HealOverlay.points({ px = 48, py = 48, balls = 6, lit = 6 }), 7,
  "a full party lights all six")
T.eq(#HealOverlay.points({ px = 48, py = 48, balls = 6, lit = 99 }), 7,
  "and a bad count cannot run off the end of the machine")

if T.failures > 0 then
  error(("heal overlay placement: %d failure(s)"):format(T.failures))
end
print(("PASS heal overlay placement (%d checks)"):format(T.checks))
