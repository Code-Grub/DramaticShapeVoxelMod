-- The three battle-UI backplate options added for the 1.66 update:
--
--   C) SPRITE LIGHT  UNLIT / SHADED   -- whether the mon cards receive the
--      world's day tint and cast shadows (SHADED) or draw flat and full
--      bright (UNLIT). UNLIT is what the white arena fill (B) needs, so the
--      cards stay readable on a solid white field.
--
--   B) ARENA FILL    WHITE / OFF       -- a solid white rendering layer in
--      front of the whole voxel world, with only the mons, their attack
--      animations and the menus above it. Hides the 3D terrain while keeping
--      the animated sprites -- the middle step between the OG battle and the
--      full voxel one. Requires sprite light UNLIT.
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

-- Whether to draw the solid white layer over the voxel world. The white
-- layer only makes sense with sprites unlit, so this also reports false when
-- the player has left sprite light on SHADED -- a white field under shaded
-- (dimmed) cards would just be a dimmer white field for no reason.
function UiBackplates.arenaWhite()
  return UiBackplates.arenaFill:get() == "WHITE"
         and UiBackplates.spritesUnlit()
end

-- ------- A) TEXTBOX FILL -------

UiBackplates.textboxFill = ModSetting.new("textboxFill", "TEXTBOX FILL",
  { "OFF", "HALF" }, { "OFF", "HALF" })

-- The backplate alpha for the dialogue text box, or nil when the backplate is
-- off. HALF is a fixed semi-transparent slab, not the frosted HUD panel -- the
-- point is a clean, bounded rectangle the text sits on, not a blurred window
-- into the world behind it. Suppressed under ARENA FILL: WHITE, where the
-- dialogue box is plain black ink on the white field with a white drop-shadow
-- (see BattleHud.shadowGlyphs) -- a half-white slab there would just wash out.
function UiBackplates.textboxAlpha()
  if UiBackplates.arenaWhite() then return nil end
  return UiBackplates.textboxFill:get() == "HALF" and 0.5 or nil
end

return UiBackplates
