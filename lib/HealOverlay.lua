-- The Pokemon Center heal overlay, put where the machine actually is.
--
-- AnimateHealingMachine (engine/overworld/healing_machine.asm) is OAM: a
-- monitor tile over the console's screen and one ball per healed mon in two
-- mirrored columns, all blinking through the jingle.  The GB draws them at
-- FIXED screen coordinates with the player's cell BG-aligned at (64,64), and
-- the engine keeps that: fxHeal paints each tile at `ha.px - 64 + dx`,
-- `ha.py - 64 + dy`, and ctx.drawFx slides the whole block onto ONE projected
-- point -- the player's own feet.
--
-- That is exactly right for a flat renderer and wrong for this one.  The art
-- belongs about 60 world pixels north of the player, on a cabinet 17 voxels
-- tall; a perspective camera foreshortens that lever arm, so a rigid -60px
-- screen slide overshoots upward and the balls and the monitor hang in the
-- air over the machine.  Measured against the machine's own surfaces the
-- block rides ~9px high at the 35 degree rung and ~14px at 50 -- and the
-- monitor and the balls drift by DIFFERENT amounts, so no single corrected
-- anchor seats them both.  Only per-piece placement does.
--
-- So this hands back world points, not a screen offset.  The drawing that
-- voxel_heights.lua extrudes into the machine and the drawing the OAM lands
-- on are the same 32x32 grid, and Buildings extrudes its front elevation by
-- one rule -- drawn row r stands at height GROUND_ROW - r, from the base's
-- last row on the floor to the console's lid.  Reading the OAM offsets
-- through that rule is all it takes: the monitor comes out on the console's
-- face inside the inset the drawing cuts for it, and the balls come out on
-- the cabinet's front panel in the two columns the fascia notches.
--
-- Kept OUT of the flat and tilt paths, which want the GB's own placement and
-- already get it.  See tests/heal_overlay_test.lua, which holds every number
-- below against the center_heal_machine template it was read off.

local V = ...

local HealOverlay = {}

-- The plot, relative to the cell the player healed on.  Not a guess: the
-- engine paints the monitor tile at flat world (px - 20, py - 44), and that
-- tile's lit rectangle is the console inset at grid (13, 6) -- so the tile's
-- top-left is grid (12, 4) and the plot's north-west corner is 32 west and
-- 48 north of the heal cell.  Whichever machine of the pair the player is
-- standing at, they are standing at it the same way.
local PLOT_DX, PLOT_DY = -32, -48

-- The plot's two front planes, in plot-local depth.  The cabinet's box runs
-- `depthPx` 10 back from `desk.z` 16, and the console stands on its lid,
-- `depth` 4 from its own `z` 20 -- so the console's face sits 2px behind the
-- cabinet's, which is why the balls and the monitor do not share a plane.
local FRONT_Z, CONSOLE_Z = 26, 24

-- The whole front elevation extrudes upward off the floor line: drawn row 31
-- is the ground, the base band climbs to 14, the fascia's two rows are the
-- lid's edge at 16 and 15, and the console's facade carries straight on
-- above it.  One rule the length of the machine.
local GROUND_ROW = 31

-- The OAM, engine-side (OverworldController's fxHeal and HEAL_BALL_XY): a
-- tile's top-left goes to flat world (ha.px - 64 + dx, ha.py - 64 + dy), so
-- its plot grid position is (dx - 32, dy - 16).  `true` is OAM_XFLIP, the
-- right-hand column.
local GRID_DX, GRID_DY = -32, -16
local MONITOR = { 44, 20 }
local BALLS = { { 40, 27 }, { 48, 27, true },
                { 40, 32 }, { 48, 32, true },
                { 40, 37 }, { 48, 37, true } }

-- Where the ink actually sits inside each 8x8 tile of the player's own
-- extracted heal_machine sheet (PokeCenterFlashingMonitorAndHealBall, found
-- through field.overworldFx like the engine finds it): the monitor's lit
-- rectangle is x 1..6, y 2..4, and the ball is x 2..7, y 2..7.  The tile is
-- mostly margin, and it is the INK that has to land on the machine, so every
-- point below is the centre of the ink.
local MONITOR_INK = { x = 4, y = 3.5 }
local BALL_INK = { x = 5, y = 5 }

-- FlashSprite8Times XORs rOBP1 ($28): the sprites never disappear, the two
-- middle shades swap in place.  ha.visible == false is that half of the beat.
local FLASH_MAP = { [0] = 0, [1] = 2, [2] = 1, [3] = 3 }

-- The plot's north-west corner in world pixels, from the heal cell.
function HealOverlay.plot(ha)
  return ha.px + PLOT_DX, ha.py + PLOT_DY
end

-- One record per piece the overlay draws, in world space:
--   kind   "monitor" or "ball"
--   x, h, z   the point the piece's ink is centred on -- east, up, south
--   flip   the right-hand ball column, drawn mirrored like its OAM
--   ink    where that centre lies inside the 8x8 tile, for the blit
local function piece(kind, px0, py0, oam, ink, plane)
  local flip = oam[3] == true
  local gx = oam[1] + GRID_DX
  local row = oam[2] + GRID_DY
  return {
    kind = kind,
    -- a mirrored tile draws leftward, so its ink centre reflects across the
    -- tile's own width rather than staying put
    x = px0 + gx + (flip and (8 - ink.x) or ink.x),
    h = GROUND_ROW - (row + ink.y),
    z = py0 + plane,
    flip = flip,
    ink = ink,
  }
end

function HealOverlay.points(ha)
  local px0, py0 = HealOverlay.plot(ha)
  local out = { piece("monitor", px0, py0, MONITOR, MONITOR_INK, CONSOLE_Z) }
  local lit = math.max(0, math.min(tonumber(ha.lit) or 0, #BALLS))
  for i = 1, lit do
    out[#out + 1] = piece("ball", px0, py0, BALLS[i], BALL_INK, FRONT_Z)
  end
  return out
end

-- The sheet, cached on the overworld state under the ENGINE's own field
-- names.  fxHeal populates these lazily too, and it still runs on the flat
-- and tilt paths, so the two share one image and one pair of quads instead
-- of each holding its own copy of an 8x16 texture.
local function sheet(state)
  local Game = require("src.core.Game")
  local field = Game.data and Game.data.field
  local def = field and field.overworldFx and field.overworldFx.healMachine
  if state.healMachineImg == nil and def then
    local ok, image = pcall(love.graphics.newImage, def.path)
    state.healMachineImg = ok and image or false
  end
  local img = state.healMachineImg
  if not img then return nil end
  if not state.healMachineQuads then
    local w, h = img:getWidth(), img:getHeight()
    state.healMachineQuads = {
      love.graphics.newQuad(0, 0, 8, 8, w, h),   -- monitor ($7c)
      love.graphics.newQuad(0, 8, 8, 8, w, h),   -- ball ($7d)
    }
  end
  return img, state.healMachineQuads
end

-- Composite the overlay into the finished scene.  `project(wx, wy, wz)`
-- answers in canvas pixels and `scale` is canvas pixels per world pixel --
-- the same two the rest of the FX pass uses.  Deliberately unscaled by
-- depth, like every other billboard here: a piece keeps its authored size
-- and only its anchor moves.
function HealOverlay.draw(ha, project, scale, ctx)
  local state = ctx and ctx.state
  if not (ha and state and project and scale) then return false end
  local img, quads = sheet(state)
  if not img then return false end

  local PaletteFX = require("src.render.PaletteFX")
  -- the flashed half of the beat recolours the sprites in place, and wins
  -- over the world's own sprite palette exactly as it does on the flat path
  local colors = (not ha.visible)
    and PaletteFX.permute(PaletteFX.GRAYS, FLASH_MAP)
    or (ctx.spriteColors and ctx.spriteColors() or nil)
  local shader = colors and PaletteFX.shader() or nil
  if shader then
    PaletteFX.sendColors(shader, colors)
    love.graphics.setShader(shader)
  end

  love.graphics.setColor(1, 1, 1, 1)
  for _, p in ipairs(HealOverlay.points(ha)) do
    local sx, sy = project(p.x, p.h, p.z)
    if sx then
      local quad = quads[p.kind == "monitor" and 1 or 2]
      local top = sy - p.ink.y * scale
      if p.flip then
        love.graphics.draw(img, quad, sx + p.ink.x * scale, top, 0, -scale, scale)
      else
        love.graphics.draw(img, quad, sx - p.ink.x * scale, top, 0, scale, scale)
      end
    end
  end

  if shader then love.graphics.setShader() end
  return true
end

return HealOverlay
