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
-- than receiving the world's day tint and shadows (SHADED). The card-draw
-- path in BattleScene calls this to decide whether to skip dayTint/shadow.
function UiBackplates.spritesUnlit()
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

-- The backplate alpha for the dialogue/menu boxes, or nil when the backplate
-- is off. HALF is a fixed semi-transparent BLACK slab (matching upstream's
-- default), not the frosted HUD panel -- a clean, bounded rectangle the text
-- sits on. Suppressed under ARENA FILL: WHITE, where the boxes are plain black
-- ink on the white field with a white drop-shadow.
function UiBackplates.textboxAlpha()
  if UiBackplates.arenaWhite() then return nil end
  return UiBackplates.textboxFill:get() == "HALF" and 0.5 or nil
end

-- Whether `key` is one of the dialogue/menu boxes that the HALF backplate
-- covers (as opposed to the HUD blocks).
function UiBackplates.isTextboxKey(key)
  return UiBackplates.TEXTBOX_KEYS[key] == true
end

return UiBackplates
