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

-- The backplate colour/alpha for the dialogue box, or nil when there is none:
--   * OFF   -- no backplate: the engine's white box fill is skipped, so the
--     diorama shows through behind the text (the box border + ink still draw).
--   * HALF  -- a translucent BLACK slab (upstream's default) over the diorama,
--     so the words read over any ground. Applied only to the dialogue box
--     (phase "messages"); the move-select / type / mimic menus keep their own
--     black-on-diorama drawing so their glyphs never become white-on-white.
-- The fill is applied by a g.rectangle shim in OverworldBattle.drawTextArea
-- (see halfBoxFill): that draws into the SAME 160x144 UI canvas the engine's
-- box lives in, so it tracks the box at every window aspect.
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

-- ------- the backplate is applied in OverworldBattle.drawTextArea
--
-- The engine draws the dialogue box through BattleState:drawTextArea, which
-- issues the white interior as a g.rectangle("fill") (see withoutBoxFill /
-- whiteBoxFill there). The backplate colour is taken from textboxFillStyle()
-- and applied by a g.rectangle shim in that path -- NOT by wrapping
-- Font.drawBox, whose own fill is bypassed during a battle draw. So the fill
-- lives in the 160x144 UI canvas the box is drawn in and tracks it at every
-- window aspect.

return UiBackplates
