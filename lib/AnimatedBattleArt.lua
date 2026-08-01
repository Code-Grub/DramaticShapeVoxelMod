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
  gen5 = V.data("animated_battle_sprites_gen5"),
}
local AnimatedBattleArt = {}

local loaded, loadOrder = {}, {}
local LOAD_LIMIT = 6
local states = setmetatable({}, { __mode = "k" }) -- battler -> playback

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
    local width = assert(tonumber(def.width))
    local height = assert(tonumber(def.height))
    local columns = assert(tonumber(def.columns))
    local count = assert(tonumber(def.frames))
    if width < 1 or height < 1 or columns < 1 or count < 1 then return end

    local sheet = love.image.newImageData(path)
    local sheetW, sheetH = sheet:getDimensions()
    local rows = math.ceil(count / columns)
    if sheetW < columns * width or sheetH < rows * height then return end

    local frames = {}
    for index = 0, count - 1 do
      local cell = love.image.newImageData(width, height)
      cell:paste(sheet, 0, 0,
        (index % columns) * width,
        math.floor(index / columns) * height,
        width, height)
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

local function restore(battler)
  local state = battler and states[battler]
  if not state then return end
  if battler.sprite == state.frames[state.frame] then
    battler.sprite = state.original
  end
  states[battler] = nil
end

local function definition(battler, side)
  local species = battler and battler.mon and battler.mon.species
  local key = species and tostring(species):upper()
  local selected = SETS[BattleArt.animationSetting:get()]
  local bySide = selected and key and selected[key]
  return bySide and bySide[side] or nil
end

local function updateBattler(battler, side, dt, mode)
  if not battler then return end
  local def = definition(battler, side)
  if not (def and battler.sprite) then restore(battler); return end

  local state = states[battler]
  if state and (state.def ~= def or state.mode ~= mode) then
    restore(battler)
    state = nil
  end
  if not state then
    local frames = loadFrames(def, mode)
    if not frames then return end -- missing/malformed atlas: retain ROM art
    state = { def = def, mode = mode, original = battler.sprite,
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

function AnimatedBattleArt.update(battle, dt)
  if not battle then return end
  if BattleArt.setting:get() ~= "animated" then
    AnimatedBattleArt.finish(battle)
    return
  end
  local mode = BattleArt.displayMode()
  updateBattler(battle.enemy, "front", dt, mode)
  updateBattler(battle.player, BattleArt.playerSide(), dt, mode)
end

function AnimatedBattleArt.finish(battle)
  if not battle then return end
  restore(battle.enemy)
  restore(battle.player)
end

function AnimatedBattleArt.invalidate()
  loaded, loadOrder = {}, {}
end

return AnimatedBattleArt
