-- XP / experience bar for the player's active mon, scaled to match the
-- battle HUD.
--
-- The drawing, animation and colour logic below is adapted from the
-- pokemon-gen1-recomp-mod-qol project by unxpected-uxp
-- (https://github.com/unxpected-uxp/pokemon-gen1-recomp-mod-qol,
--  qol_feature_xp_bar.lua), used with the author's permission. The original
-- draws the bar at a fixed GB-frame position (EXP_X, EXP_Y) at scale 1; this
-- port recomputes the position/scale from the SAME transform the player HUD
-- uses (OverworldBattle.snapRects -> hs = scale - 1), so the bar sits at the
-- exact player-HUD location and shrinks to the same "a bit smaller" size as
-- the HUD, for any window size or camera composition. It is drawn into the
-- world canvas (shot.canvas) during drawHudPanels, so it works on every
-- platform including iOS (where snapHUDs is skipped).
--
-- the mod namespace (see main.lua): V.require loads a sibling module
local V = ...

local ModSetting = V.require("ModSetting")
local OverworldBattle = V.require("OverworldBattle")

-- engine modules (same as the QoL source)
local Growth = require("src.pokemon.Growth")
local PaletteFX = require("src.render.PaletteFX")

local ExpBar = {}

-- ------- enable toggle (OPTIONS row + persisted, like the other backplates) -------

ExpBar.enabled = ModSetting.new("BattleArtXpBar", "BATTLE ART XP BAR",
  { "OFF", "ON" }, { "OFF", "ON" })

-- ------- constants (from the QoL source) -------

local EXP_X, EXP_Y, EXP_WIDTH = 80, 89, 67
local EXP_LEVEL_HOLD_FRAMES = 30
local EXP_BURST_DIAGONALS = { 0, 1, 2, 4, 5, 7, 8, 9 }
local EXP_BLUE = { 50 / 255, 150 / 255, 250 / 255, 1 }
local EXP_BLACK = { 0, 0, 0, 1 }

-- ------- colour -------

local function paletteExpColor(battle)
  local colors = battle.zoneColorsAt
    and battle:zoneColorsAt(EXP_X, EXP_Y)
  if not colors then return EXP_BLACK end
  local bgp = battle.activeBgp and battle:activeBgp()
  colors = PaletteFX.effectiveColors(PaletteFX.permute(colors, bgp))
  local color = colors and colors[3]
  if not color then return EXP_BLACK end
  return { color[1] / 255, color[2] / 255, color[3] / 255, 1 }
end

-- ------- progress -------

local function expPixels(battle)
  local mon = battle.player and battle.player.mon
  local def = mon and battle.data.pokemon[mon.species]
  if not def then return 0 end
  local cap = battle.data.constants and battle.data.constants.levelCap or 100
  if mon.level >= cap then return EXP_WIDTH end
  local current = Growth.expForLevel(def.growthRate, mon.level,
                                     battle.data.growth_rates)
  local nextLevel = Growth.expForLevel(def.growthRate, mon.level + 1,
                                       battle.data.growth_rates)
  local needed = nextLevel - current
  if needed <= 0 then return 0 end
  local progress = math.max(0, math.min(needed, mon.exp - current))
  return math.floor(progress * EXP_WIDTH / needed)
end

-- per-battle animation state (single active battle at a time; expMon change
-- resets it, as in the source)
local expState = {}

local function animatedExpPixels(battle)
  local mon = battle.player and battle.player.mon
  local target = expPixels(battle)
  local state = expState
  if state.expMon ~= mon or state.expPixels == nil then
    state.expMon = mon
    state.expPixels = target
    state.expLevel = mon and mon.level
    state.expPhase = nil
    state.expLevelCycles = 0
    state.expBurstFrame = nil
    state.expFrame = battle.frame
    return target
  end
  if state.expFrame == battle.frame then return state.expPixels end
  state.expFrame = battle.frame

  local level = mon and mon.level or state.expLevel
  if level and state.expLevel and level > state.expLevel then
    state.expLevelCycles = (state.expLevelCycles or 0) + level - state.expLevel
    state.expLevel = level
    if not state.expPhase then state.expPhase = "fill_level" end
  elseif level and level ~= state.expLevel then
    state.expLevel = level
  end

  if state.expPhase == "fill_level" then
    state.expPixels = math.min(EXP_WIDTH, state.expPixels + 1)
    if state.expPixels == EXP_WIDTH then
      state.expPhase = "hold_level"
      state.expHoldFrames = EXP_LEVEL_HOLD_FRAMES
      state.expBurstFrame = 0
    end
  elseif state.expPhase == "hold_level" then
    if state.expBurstFrame then
      if state.expBurstFrame < #EXP_BURST_DIAGONALS - 1 then
        state.expBurstFrame = state.expBurstFrame + 1
      else
        state.expBurstFrame = nil
      end
    end
    if state.expHoldFrames > 0 then
      state.expHoldFrames = state.expHoldFrames - 1
    else
      state.expLevelCycles = math.max(0, (state.expLevelCycles or 1) - 1)
      local cap = battle.data.constants and battle.data.constants.levelCap or 100
      state.expBurstFrame = nil
      if state.expLevelCycles > 0 then
        state.expPixels = 0
        state.expPhase = "fill_level"
      elseif mon and mon.level >= cap then
        state.expPhase = nil
        state.expPixels = EXP_WIDTH
      else
        state.expPixels = 0
        state.expPhase = "after_level"
      end
    end
  elseif state.expPhase == "after_level" then
    state.expPixels = math.min(target, state.expPixels + 1)
    if state.expPixels >= target then state.expPhase = nil end
  elseif state.expPixels < target then
    state.expPixels = math.min(target, state.expPixels + 1)
  elseif state.expPixels > target then
    state.expPixels = math.max(target, state.expPixels - 1)
  end
  return state.expPixels
end

-- ------- burst particles (level-up) -------

local EXP_BURST_TILE_ROWS = {
  "oooooooo",
  "oooxxooo",
  "ooxxxxoo",
  "oxxxxxxo",
  "oxxxxxxo",
  "ooxxxxoo",
  "oooxxooo",
  "oooooooo",
}

local function drawExpBurst(frame, centerX, centerY, scale, color)
  if frame == nil then return end
  local g = love.graphics
  local radius = frame * 2 * scale
  local diagonal = EXP_BURST_DIAGONALS[frame + 1] * scale

  local function particle(dx, dy)
    local x = centerX + dx - 4 * scale
    local y = centerY + dy - 4 * scale
    for py, row in ipairs(EXP_BURST_TILE_ROWS) do
      for px = 1, 8 do
        if row:sub(px, px) == "x" then
          local dotX = x + (px - 1) * scale
          local dotY = y + (py - 1) * scale
          g.rectangle("fill", dotX, dotY, scale, scale)
        end
      end
    end
  end

  g.setShader()
  g.setColor(color[1], color[2], color[3], color[4])
  particle(radius, 0)
  particle(diagonal, diagonal)
  particle(0, radius)
  particle(-diagonal, diagonal)
  particle(-radius, 0)
  particle(-diagonal, -diagonal)
  particle(0, -radius)
  particle(diagonal, -diagonal)
end

-- ------- draw, scaled + anchored to the player HUD -------

-- Called from OverworldBattle.drawHudPanels, with shot.canvas bound (the world
-- surface). Uses the same snapRects transform as the player HUD so the bar
-- lands at the HUD's exact location and the same hs scale.
function ExpBar.draw(battle, shot)
  if ExpBar.enabled:get() ~= "ON" then return end
  if not battle.player or battle.safari or battle.demo
     or battle.showPlayerBack then return end
  if battle.introSlide and battle.introSlide ~= 0 then return end
  if not shot or not shot.scale then return end

  local colorMode = PaletteFX.mode
  local blue = colorMode == "ogred" or colorMode == "gbc"
    or colorMode == "redpp"
  local color = blue and EXP_BLUE or paletteExpColor(battle)

  local px = animatedExpPixels(battle)
  if px <= 0 then return end

  -- player HUD world rect + the hs scale it was drawn at
  local rects, bands = OverworldBattle.snapRects(shot)
  local pr = rects.player
  local hs = bands.player.scale
  local HUD = OverworldBattle.HUD_RECT.player   -- { 72, 56, 88, 40 }
  -- EXP_X/EXP_Y are GB-frame coords inside the player HUD block; offset from
  -- the HUD's origin by the same hs the HUD used.
  local barX = pr[1] + (EXP_X - HUD[1]) * hs
  local barY = pr[2] + (EXP_Y - HUD[2]) * hs
  local w = px * hs
  local h = 2 * hs

  local g = love.graphics
  g.setShader()
  g.setColor(color[1], color[2], color[3], color[4])
  g.rectangle("fill", barX, barY, w, h)

  -- level-up burst, centred on the full bar
  drawExpBurst(expState.expBurstFrame,
    barX + EXP_WIDTH * hs / 2, barY + h / 2, hs, color)
end

return ExpBar
