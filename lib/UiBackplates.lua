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
-- for free, and persists under options.modOptions.DRAMATIC_SHAPE like the
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
  { "OFF", "HALF" }, { "OFF", "HALF" })

-- The rect keys whose dialogue/menu boxes get the HALF backplate. The bottom
-- text box ("box") and the move-select / mimic-select menus that open over it
-- -- NOT the player/opponent HUD blocks, which are separate rects.
UiBackplates.TEXTBOX_KEYS = { box = true, moves = true, mimic = true }

-- The backplate colour/alpha for the dialogue/menu boxes, or nil when there
-- is none. Two cases:
--   * ARENA FILL: WHITE -- an OPAQUE WHITE slab, so no sprite (e.g. the mon
--     standing behind the box) shows through; the box reads as a solid white
--     Game Boy panel with the inverted black ink on top.
--   * TEXTBOX FILL: HALF -- a translucent BLACK slab (upstream's default), so
--     the words read over any ground.
-- The player/opponent HUD blocks are never covered (see isTextboxKey).
function UiBackplates.textboxFillStyle()
  if UiBackplates.arenaWhite() then return { 1, 1, 1, 1 } end
  if UiBackplates.textboxFill:get() == "HALF" then
    return { 0, 0, 0, 0.5 }
  end
  return nil
end

-- Whether `key` is one of the dialogue/menu boxes that the HALF backplate
-- covers (as opposed to the HUD blocks).
function UiBackplates.isTextboxKey(key)
  return UiBackplates.TEXTBOX_KEYS[key] == true
end

return UiBackplates
