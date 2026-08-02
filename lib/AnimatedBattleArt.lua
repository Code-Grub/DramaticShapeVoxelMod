-- Runtime playback for authoring-time GIF conversions.
--
-- LÖVE does not decode animated GIFs. The importer flattens each GIF into a
-- PNG atlas and one generated data table per set records the logical cell and
-- timing data. This module extracts exact ImageData rectangles: no Canvas DPI
-- participates, so one source pixel remains one logical battle-art pixel.
local V = ...

local BattleArt = V.require("BattleArt")
local SETS = {
  gen2 = V.data("animated_battle_sprites_gen2"),
  gen3 = V.data("animated_battle_sprites_gen3"),
  gen4 = V.data("animated_battle_sprites_gen4"),
  gen5 = V.data("animated_battle_sprites_gen5"),
}
local BACK_SETS = {
  gen3 = V.data("animated_battle_backs_gen3"),
  gen5 = SETS.gen5,
}
-- Gen 1 SGB, Gen 2 Crystal, and Gen 4 backs are intentionally single-frame
-- collections even while BATTLE ART is ANIMATED. Keeping this allowlist
-- narrow prevents a static generation folder from being decoded as an atlas.
local ANIMATED_BACK_SETS = { gen3 = true, gen5 = true }
local PLAYER_SETS = V.data("animated_player_trainers")
local AnimatedBattleArt = {}

local loaded, loadOrder = {}, {}
local LOAD_LIMIT = 6
local states = setmetatable({}, { __mode = "k" }) -- battler -> playback
local trainerStates = setmetatable({}, { __mode = "k" }) -- battle -> playback

local function currentImage(state)
  if not state then return nil end
  return state.frames and state.frames[state.frame] or state.image
end

local function forgetFromOrder(def)
  for i = #loadOrder, 1, -1 do
    if loadOrder[i] == def then table.remove(loadOrder, i) end
  end
end

local function remember(def, mode, frames)
  forgetFromOrder(def)
  loaded[def] = { mode = mode, frames = frames }
  loadOrder[#loadOrder + 1] = def
  if #loadOrder > LOAD_LIMIT then
    local old = table.remove(loadOrder, 1)
    loaded[old] = nil
  end
end

local function atlasPath(def)
  local path = def and def.image and V.mod.assets:path(def.image)
  local fs = love and love.filesystem
  if not (path and fs and fs.getInfo and fs.getInfo(path)) then return nil end
  return path
end

local function loadFrames(def, mode)
  local hit = loaded[def]
  if hit and hit.mode == mode then return hit.frames end

  local path = atlasPath(def)
  if not path then return nil end
  local result
  local ok = pcall(function()
    local sheet = love.image.newImageData(path)
    local sheetW, sheetH = sheet:getDimensions()
    local frames = {}
    local cells = def.cells
    local autoColumns = tonumber(def.autoColumns)
    local count = cells and #cells or autoColumns or assert(tonumber(def.frames))
    if count < 1 then return end
    local autoWidth
    if autoColumns then
      if autoColumns % 1 ~= 0 or sheetW % autoColumns ~= 0 then return end
      autoWidth = sheetW / autoColumns
    end
    for index = 0, count - 1 do
      local x, y, width, height
      if cells then
        local c = cells[index + 1]
        x, y = tonumber(c.x) or 0, tonumber(c.y) or 0
        width, height = assert(tonumber(c.width)), assert(tonumber(c.height))
      elseif autoColumns then
        x, y = index * autoWidth, 0
        width, height = autoWidth, sheetH
      else
        width = assert(tonumber(def.width))
        height = assert(tonumber(def.height))
        local columns = assert(tonumber(def.columns))
        x = (index % columns) * width
        y = math.floor(index / columns) * height
      end
      if width < 1 or height < 1 or x < 0 or y < 0
         or x + width > sheetW or y + height > sheetH then return end
      local cell = love.image.newImageData(width, height)
      cell:paste(sheet, 0, 0, x, y, width, height)
      local image = BattleArt.prepareData(cell, mode)
      if not image then return end
      frames[#frames + 1] = image
    end
    if #frames == count then result = frames end
  end)
  if not ok or not result then return nil end
  remember(def, mode, result)
  return result
end

local function restoreTrainer(battle)
  local state = battle and trainerStates[battle]
  if not state then return end
  if battle.playerBackPic == state.frames[state.frame] then
    battle.playerBackPic = state.original
  end
  trainerStates[battle] = nil
end

-- Five authored poses are tied to SlideTrainerPicOffScreen rather than to a
-- free-running clock. Frame one waits with the stationary intro portrait;
-- frames two through five divide the 72-pixel leftward walk, then clamp.
local function updatePlayerTrainer(battle, mode)
  if not (battle and battle.showPlayerBack and not battle.demo) then
    restoreTrainer(battle)
    return
  end
  local selected = BattleArt.playerAnimationSetting:get()
  local def = selected ~= "rom" and PLAYER_SETS[selected] or nil
  if not def or not battle.playerBackPic then
    restoreTrainer(battle)
    return
  end
  local state = trainerStates[battle]
  if state and (state.def ~= def or state.mode ~= mode) then
    restoreTrainer(battle)
    state = nil
  end
  if not state then
    local frames = loadFrames(def, mode)
    if not frames then return end
    state = { def = def, mode = mode, original = battle.playerBackPic,
              frames = frames, frame = 1 }
    trainerStates[battle] = state
  elseif battle.playerBackPic ~= state.frames[state.frame]
     and battle.playerBackPic ~= state.original then
    trainerStates[battle] = nil
    return
  end

  local offset = 0
  if type(battle.picOffset) == "function" then
    local ok, got = pcall(battle.picOffset, battle, "back")
    if ok then offset = tonumber(got) or 0 end
  end
  local progress = math.max(0, math.min(72, -offset))
  if progress <= 0 then
    state.frame = 1
  else
    local movingFrames = math.max(1, #state.frames - 1)
    state.frame = math.min(#state.frames,
      2 + math.floor(math.max(0, progress - 1) * movingFrames / 72))
  end
  battle.playerBackPic = state.frames[state.frame]
end

local function restore(battler)
  local state = battler and states[battler]
  if not state then return end
  if battler.sprite == currentImage(state) then
    battler.sprite = state.original
  end
  states[battler] = nil
end

local function definition(battler, side)
  local species = battler and battler.mon and battler.mon.species
  local key = species and tostring(species):upper()
  local setting = side == "back" and BattleArt.backAnimationSetting
                                  or BattleArt.frontAnimationSetting
  local collections = side == "back" and BACK_SETS or SETS
  local selected = collections[setting:get()]
  local bySide = selected and key and selected[key]
  return bySide and bySide[side] or nil
end

local function updateBattler(battler, side, dt, mode)
  if not battler then return end
  local def = definition(battler, side)
  if not (def and battler.sprite) then restore(battler); return end

  local state = states[battler]
  if state and (state.kind ~= "animated" or state.def ~= def
                or state.mode ~= mode or state.side ~= side) then
    restore(battler)
    state = nil
  end
  if not state then
    local frames = loadFrames(def, mode)
    if not frames then return end -- missing/malformed atlas: retain ROM art
    state = { kind = "animated", side = side, def = def, mode = mode,
              original = battler.sprite,
              frames = frames, frame = 1, elapsed = 0 }
    states[battler] = state
  elseif battler.sprite ~= state.frames[state.frame]
     and battler.sprite ~= state.original then
    -- Transform or another battle effect owns the sprite now.
    states[battler] = nil
    return
  end

  state.elapsed = state.elapsed + (tonumber(dt) or 0)
  local durations = def.durations or {}
  local duration = math.max(1, tonumber(durations[state.frame]) or 100) / 1000
  while state.elapsed >= duration do
    state.elapsed = state.elapsed - duration
    state.frame = state.frame % #state.frames + 1
    duration = math.max(1, tonumber(durations[state.frame]) or 100) / 1000
  end
  battler.sprite = state.frames[state.frame]
end

local function updateStaticBack(battler, generation, mode)
  if not (battler and battler.sprite) then return end
  local species = battler.mon and battler.mon.species
  local image = species and BattleArt.generationBackImage(species, generation)
  local state = states[battler]
  if state and (state.kind ~= "static" or state.generation ~= generation
                or state.mode ~= mode or state.image ~= image) then
    restore(battler)
    state = nil
  end
  if not image then restore(battler); return end
  if not state then
    state = { kind = "static", side = "back", generation = generation,
              mode = mode, original = battler.sprite, image = image }
    states[battler] = state
  elseif battler.sprite ~= state.image and battler.sprite ~= state.original then
    -- A transform or battle effect owns the sprite for this frame.
    states[battler] = nil
    return
  end
  battler.sprite = state.image
end

function AnimatedBattleArt.update(battle, dt)
  if not battle then return end
  if BattleArt.setting:get() ~= "animated" then
    AnimatedBattleArt.finish(battle)
    return
  end
  local mode = BattleArt.displayMode()
  -- Restore a static PLAYER ART replacement before the animation manager
  -- captures the engine portrait, then leave managed animation frames alone.
  BattleArt.applyTrainers(battle)
  updatePlayerTrainer(battle, mode)
  updateBattler(battle.enemy, "front", dt, mode)
  local playerSide = BattleArt.playerSide()
  if playerSide == "back" then
    local generation = BattleArt.backAnimationSetting:get()
    if ANIMATED_BACK_SETS[generation] then
      updateBattler(battle.player, "back", dt, mode)
    else
      updateStaticBack(battle.player, generation, mode)
    end
  else
    updateBattler(battle.player, "front", dt, mode)
  end
end

-- The staged renderer asks this before deciding whether to suppress the
-- engine's original player pics layer. A managed back image belongs in the
-- world; no managed image means the selected file/atlas was absent or bad,
-- so the untouched ROM backsprite remains attached to the UI.
function AnimatedBattleArt.hasWorldBack(battler)
  local state = battler and states[battler]
  return state and state.side == "back"
         and battler.sprite == currentImage(state) or false
end

-- UI scaling needs to distinguish our native-resolution trainer atlas from
-- the ROM's deliberately half-resolution back picture. Both occupy the same
-- engine field, but only the ROM image should receive the Game Boy 2x scale.
function AnimatedBattleArt.hasPlayerTrainerFrame(battle)
  local state = battle and trainerStates[battle]
  return state and battle.playerBackPic == currentImage(state) or false
end

function AnimatedBattleArt.finish(battle)
  if not battle then return end
  restoreTrainer(battle)
  restore(battle.enemy)
  restore(battle.player)
end

function AnimatedBattleArt.invalidate()
  loaded, loadOrder = {}, {}
  trainerStates = setmetatable({}, { __mode = "k" })
end

return AnimatedBattleArt
