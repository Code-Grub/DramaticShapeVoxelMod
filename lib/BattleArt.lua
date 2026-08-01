-- Optional, user-supplied battle art. Nothing in these folders is used by
-- the Pokedex, party menu or status screen.
local V = ...

local ModSetting = V.require("ModSetting")
local BattleArt = {}

BattleArt.setting = ModSetting.new("battleArt", "BATTLE ART",
  { "static", "animated", "rom" }, { "STATIC", "ANIMATED", "ROM" })
BattleArt.viewSetting = ModSetting.new("playerView", "PLAYER VIEW",
  { "front", "back" }, { "FRONT", "BACK" })

local cache = {}
local external = setmetatable({}, { __mode = "k" })
local metrics = setmetatable({}, { __mode = "k" })
local original = setmetatable({}, { __mode = "k" })
local trainerOriginal = setmetatable({}, { __mode = "k" })

local function slug(species)
  local s = tostring(species or ""):lower()
  s = s:gsub("♀", "-f"):gsub("♂", "-m")
  s = s:gsub("['’%.]", "")
  s = s:gsub("[^%w]+", "-"):gsub("^-+", ""):gsub("-+$", "")
  return s
end
BattleArt.slug = slug

function BattleArt.playerSide()
  return BattleArt.viewSetting:get() == "back" and "back" or "front"
end

local function pathFor(species, side)
  local mode = BattleArt.setting:get()
  if mode == "rom" then return nil end
  -- Animated atlases need frame rectangles/timing, not just an image path.
  -- Keep the folder and setting stable while that decoder is added; an
  -- unrecognised atlas must never appear as one giant sprite sheet.
  if mode == "animated" then return nil end
  local rel = ("assets/battle/%s-%s/%s.png"):format(
    side, "static", slug(species))
  local path = V.mod.assets:path(rel)
  local fs = love and love.filesystem
  if not (fs and fs.getInfo and fs.getInfo(path)) then return nil end
  return path, rel
end

local function staticPathFor(name, side)
  if BattleArt.setting:get() == "rom" then return nil end
  local path = V.mod.assets:path(
    ("assets/battle/%s-static/%s.png"):format(side, name))
  local fs = love and love.filesystem
  return fs and fs.getInfo and fs.getInfo(path) and path or nil
end

local function rgbaKey(data, w, h)
  local corners = { {0, 0}, {w - 1, 0}, {0, h - 1}, {w - 1, h - 1} }
  local counts, values, order = {}, {}, {}
  for _, p in ipairs(corners) do
    local r, g, b = data:getPixel(p[1], p[2])
    local key = (math.floor(r * 255 + .5) * 65536)
              + (math.floor(g * 255 + .5) * 256)
              + math.floor(b * 255 + .5)
    counts[key] = (counts[key] or 0) + 1
    values[key] = { r, g, b }
    if counts[key] == 1 then order[#order + 1] = key end
  end
  local best, n = order[1], -1
  for _, k in ipairs(order) do
    local count = counts[k]
    if count > n then best, n = k, count end
  end
  return values[best]
end

local function displayMode()
  local ok, fx = pcall(require, "src.render.PaletteFX")
  return ok and fx and fx.mode or "gbc"
end
BattleArt.displayMode = displayMode

local function applyDisplayFilter(data, mode)
  if mode == "gbc_inv" then
    data:mapPixel(function(_, _, r, g, b, a)
      if a <= 0 then return r, g, b, a end
      return 1 - r, 1 - g, 1 - b, a
    end)
    return
  end
  if mode ~= "og" and mode ~= "og_inv" and mode ~= "classic" then return end
  local PaletteFX = require("src.render.PaletteFX")
  local colors = PaletteFX.effectiveColors(PaletteFX.GRAYS)
  data:mapPixel(function(_, _, r, g, b, a)
    if a <= 0 then return r, g, b, a end
    local luma = r * 0.2126 + g * 0.7152 + b * 0.0722
    local i = luma > 0.83 and 1 or luma > 0.5 and 2
              or luma > 0.17 and 3 or 4
    local c = colors[i]
    return c[1] / 255, c[2] / 255, c[3] / 255, a
  end)
end

-- Turn one logical sprite image into battle-ready art. Animated atlases use
-- this same path after extracting a cell, so static and animated art receive
-- identical transparency keying, display-palette filtering and anchoring.
function BattleArt.prepareData(data, mode)
  local made
  local ok = pcall(function()
    local w, h = data:getDimensions()
    if w < 1 or h < 1 then return end

    local opaque = true
    for y = 0, h - 1 do
      for x = 0, w - 1 do
        local _, _, _, a = data:getPixel(x, y)
        if a < 0.999 then opaque = false break end
      end
      if not opaque then break end
    end

    -- Fully opaque art commonly carries a flat matte. Infer it from the
    -- corners and remove only matching pixels connected to the border, so a
    -- matching eye/highlight enclosed by the silhouette is preserved.
    if opaque then
      local key = rgbaKey(data, w, h)
      local seen, stack, top = {}, {}, 0
      local function push(x, y)
        if x < 0 or y < 0 or x >= w or y >= h then return end
        local i = y * w + x
        if seen[i] then return end
        local r, g, b = data:getPixel(x, y)
        if math.abs(r - key[1]) > 0.5 / 255
           or math.abs(g - key[2]) > 0.5 / 255
           or math.abs(b - key[3]) > 0.5 / 255 then return end
        seen[i], top = true, top + 1
        stack[top] = i
      end
      for x = 0, w - 1 do push(x, 0); push(x, h - 1) end
      for y = 0, h - 1 do push(0, y); push(w - 1, y) end
      while top > 0 do
        local i = stack[top]; stack[top], top = nil, top - 1
        local x, y = i % w, math.floor(i / w)
        local r, g, b = data:getPixel(x, y)
        data:setPixel(x, y, r, g, b, 0)
        push(x - 1, y); push(x + 1, y); push(x, y - 1); push(x, y + 1)
      end
    end

    applyDisplayFilter(data, mode)

    local x0, x1, y0, y1 = w, -1, h, -1
    for y = 0, h - 1 do
      for x = 0, w - 1 do
        local _, _, _, a = data:getPixel(x, y)
        if a > 0.001 then
          if x < x0 then x0 = x end; if x > x1 then x1 = x end
          if y < y0 then y0 = y end; if y > y1 then y1 = y end
        end
      end
    end
    if x1 < x0 then return end
    made = love.graphics.newImage(data)
    made:setFilter("nearest", "nearest")
    external[made] = true
    metrics[made] = { x0 = x0, x1 = x1, y0 = y0, y1 = y1,
                      w = w, h = h, padBottom = h - 1 - y1,
                      center = (x0 + x1 + 1) / 2 }
  end)
  return (ok and made) or nil
end

local function prepare(path, mode)
  local cacheKey = path .. "#" .. mode
  local hit = cache[cacheKey]
  if hit ~= nil then return hit or nil end
  local made
  local ok = pcall(function()
    made = BattleArt.prepareData(love.image.newImageData(path), mode)
  end)
  cache[cacheKey] = (ok and made) or false
  return made
end

function BattleArt.image(species, side)
  local path = pathFor(species, side)
  return path and prepare(path, displayMode()) or nil
end

function BattleArt.namedImage(name, side)
  local path = staticPathFor(name, side)
  return path and prepare(path, displayMode()) or nil
end

local function trainerKey(battle)
  local id = battle and battle.oppClass
  if type(id) ~= "string" then return nil end
  if id == "OPP_ROCKET" and (battle.dramaticShapeTrainerParty or 1) >= 42 then
    return "jessie-james"
  end
  return slug(id:gsub("^OPP_", ""))
end

local function replaceTrainerField(battle, field, img)
  local rec = trainerOriginal[battle]
  if not rec then rec = {}; trainerOriginal[battle] = rec end
  local saved = field .. "Saved"
  if img then
    if not rec[saved] then
      rec[field], rec[saved] = battle[field] or false, true
    end
    battle[field] = img
  elseif rec[saved] then
    battle[field] = rec[field] or nil
    rec[field], rec[saved] = nil, nil
  end
end

function BattleArt.applyTrainers(battle)
  if not battle then return end
  local enemy = battle.showEnemyTrainer and trainerKey(battle) or nil
  replaceTrainerField(battle, "trainerPic",
    enemy and BattleArt.namedImage(enemy, "front") or nil)

  local player
  if battle.showPlayerBack then
    if battle.demo then
      player = tostring(battle.demoName or ""):find("OAK", 1, true)
               and "oak" or "old-man"
    else
      player = "player"
    end
  end
  replaceTrainerField(battle, "playerBackPic",
    player and BattleArt.namedImage(player, "back") or nil)
end

function BattleArt.apply(battle)
  if not battle then return end
  local function applyOne(battler, side)
    local species = battler and battler.mon and battler.mon.species
    if not species then return end
    -- AnimatedBattleArt owns Pokemon sprites in this mode. Trainers still
    -- pass through applyTrainers below because trainer art is always static.
    if BattleArt.setting:get() == "animated" then
      if original[battler] then
        battler.sprite, original[battler] = original[battler], nil
      end
      return
    end
    local img = BattleArt.image(species, side)
    if img then
      if not BattleArt.isExternal(battler.sprite) then
        original[battler] = battler.sprite
      end
      battler.sprite = img
    elseif original[battler] then
      battler.sprite, original[battler] = original[battler], nil
    end -- otherwise retain the ROM image
  end
  applyOne(battle.enemy, "front")
  applyOne(battle.player, BattleArt.playerSide())
  BattleArt.applyTrainers(battle)
end

function BattleArt.isExternal(img) return external[img] and true or false end
function BattleArt.metrics(img) return metrics[img] end

function BattleArt.invalidate()
  cache = {}
  external = setmetatable({}, { __mode = "k" })
  metrics = setmetatable({}, { __mode = "k" })
  original = setmetatable({}, { __mode = "k" })
  trainerOriginal = setmetatable({}, { __mode = "k" })
end

return BattleArt
