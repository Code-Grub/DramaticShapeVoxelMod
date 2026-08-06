-- The three battle-UI backplate options added for the 1.66 update:
--
--   C) SPRITE LIGHT  UNLIT / SHADED   -- whether the mon cards receive the
--      world's day tint and cast shadows (SHADED) or draw flat and full
--      bright (UNLIT). UNLIT keeps them readable on the white arena fill (B);
--      SHADED is the default OG look and is also supported on white.

--   B) ARENA FILL    WHITE / OFF       -- a solid white rendering layer in
--      front of the whole voxel world, with only the mons, their attack
--      animations and the menus above it. Hides the 3D terrain while keeping
--      the animated sprites -- the middle step between the OG battle and the
--      full voxel one. Works with SHADED or UNLIT sprites (UNLIT just keeps
--      the cards brighter on white).
--
--   A) TEXTBOX FILL   HALF / OFF       -- a semi-transparent backplate behind
--      the dialogue text box ONLY (the bottom 48px of the 160x144 battle
--      screen, GB-frame rect {0,96,160,48}). The player and opponent HUD
--      blocks are separate rects and are never covered.
--
-- Each is a ModSetting: it gets an OPTIONS-menu row and a mod-manager schema
-- for free, and persists under options.modOptions.BATTLE_ART_VOXEL_FORK like the
-- others. Defining them here -- rather than inline in main.lua -- keeps the
-- three of them, and the render-path queries they answer, in one place.

-- the mod namespace (see main.lua): V.require loads a sibling module
local V = ...

local ModSetting = V.require("ModSetting")

local UiBackplates = {}

-- ------- C) SPRITE LIGHT -------

UiBackplates.spriteLight = ModSetting.new("spriteLight", "SPRITE LIGHT",
  { "SHADED", "UNLIT" }, { "SHADED", "UNLIT" })

-- Whether the mon cards should be drawn flat and full bright (UNLIT) rather
-- than receiving the world's day tint and shadows (SHADED). ARENA FILL: WHITE
-- forces this on: a solid white battle field carries no night tint -- as in
-- the traditional games -- so the sprites draw flat and true-colour
-- regardless of the SPRITE LIGHT setting.
function UiBackplates.spritesUnlit()
  if UiBackplates.arenaWhite() then return true end
  return UiBackplates.spriteLight:get() == "UNLIT"
end

-- ------- B) ARENA FILL -------

UiBackplates.arenaFill = ModSetting.new("arenaFill", "ARENA FILL",
  { "OFF", "WHITE" }, { "OFF", "WHITE" })

-- Whether to draw the solid white layer over the voxel world. Decoupled from
-- sprite light: it works with SHADED cards too (they just read a little
-- dimmer on white), so WHITE is offered independently of UNLIT.
function UiBackplates.arenaWhite()
  return UiBackplates.arenaFill:get() == "WHITE"
end

-- ------- A) TEXTBOX FILL -------

UiBackplates.textboxFill = ModSetting.new("textboxFill", "TEXTBOX FILL",
  { "OFF", "HALF" }, { "OFF", "HALF" }, 2)

-- The rect keys whose dialogue/menu boxes get the HALF backplate. The bottom
-- text box ("box") and the move-select / mimic-select menus that open over it
-- -- NOT the player/opponent HUD blocks, which are separate rects.
UiBackplates.TEXTBOX_KEYS = { box = true, moves = true, mimic = true }

-- The backplate colour/alpha for the dialogue/menu boxes, or nil when there
-- is none:
--   * OFF   -- no backplate: the engine's white box fill is skipped, so the
--     diorama shows through behind the text (the box border + ink still draw).
--   * HALF  -- a translucent BLACK slab (upstream's default) over the diorama,
--     so the words read over any ground.
-- The fill is applied by wrapping the engine's Font.drawBox (see
-- installBoxHook): that draws into the SAME 160x144 UI canvas the engine's
-- box lives in, so it tracks the box at every window aspect -- a slab in the
-- world canvas could never follow a box the engine letterboxes.
function UiBackplates.textboxFillStyle()
  -- ARENA FILL: WHITE paints a solid white field; a dark box backplate would
  -- read as a grey slab on white, so HALF is overridden to an OPAQUE WHITE
  -- fill -- the box becomes a plain white Game Boy panel, no sprite shows
  -- through, and the inverted black ink sits on top of it.
  if UiBackplates.arenaWhite() then return { 1, 1, 1, 1 } end
  if UiBackplates.textboxFill:get() == "HALF" then
    return { 0, 0, 0, 0.55 }
  end
  return nil
end

-- Whether `key` is one of the dialogue/menu boxes that the HALF backplate
-- covers (as opposed to the HUD blocks).
function UiBackplates.isTextboxKey(key)
  return UiBackplates.TEXTBOX_KEYS[key] == true
end

-- ------- the engine box hook
--
-- The engine draws the dialogue box with Font.drawBox: a white interior fill
-- in the 160x144 UI canvas (tile coords) plus a black border. We wrap it so
-- the dialogue box during a battle uses TEXTBOX FILL instead:
--   OFF  -- skip the white fill (backplate invisible; border + ink remain)
--   HALF -- draw our translucent-black fill, then the border
-- Every other box (menus, summary, overworld) is passed through untouched.
-- Gated on a live battle session so only the battle dialogue box is affected.
--
-- The battle dialogue box is the unique tile rect {0, 12, 20, 6}
-- (160x48px at the foot of the 160x144 screen).
local BOX_TX, BOX_TY, BOX_TW, BOX_TH = 0, 12, 20, 6

function UiBackplates.installBoxHook()
  local okF, Font = pcall(require, "src.render.Font")
  if not okF or not Font or not Font.drawBox then return end
  if Font.__dramaticShapeBoxHook then return end
  local inner = Font.drawBox
  local OverworldBattle = V.require("OverworldBattle")

  Font.drawBox = function(tx, ty, tw, th)
    if OverworldBattle.session
       and tx == BOX_TX and ty == BOX_TY
       and tw == BOX_TW and th == BOX_TH then
      local style = UiBackplates.textboxFillStyle()
      -- border only (in the caller's colour, as the engine does after the
      -- fill) -- copied from Font.drawBox so we can skip/replace the fill
      local r, g, b, a = love.graphics.getColor()
      if style then
        love.graphics.setColor(style[1], style[2], style[3], style[4])
        love.graphics.rectangle("fill", tx * 8, ty * 8, tw * 8, th * 8)
      end
      -- border in black (the dialogue box border colour)
      love.graphics.setColor(0, 0, 0, 1)
      local B = Font.BORDER
      Font.drawCode(B.tl, tx * 8, ty * 8)
      Font.drawCode(B.tr, (tx + tw - 1) * 8, ty * 8)
      Font.drawCode(B.bl, tx * 8, (ty + th - 1) * 8)
      Font.drawCode(B.br, (tx + tw - 1) * 8, (ty + th - 1) * 8)
      for i = 1, tw - 2 do
        Font.drawCode(B.h, (tx + i) * 8, ty * 8)
        Font.drawCode(B.h, (tx + i) * 8, (ty + th - 1) * 8)
      end
      for j = 1, th - 2 do
        Font.drawCode(B.v, tx * 8, (ty + j) * 8)
        Font.drawCode(B.v, (tx + tw - 1) * 8, (ty + j) * 8)
      end
      love.graphics.setColor(r, g, b, a)
      return
    end
    return inner(tx, ty, tw, th)
  end
  Font.__dramaticShapeBoxHook = true
end

return UiBackplates
