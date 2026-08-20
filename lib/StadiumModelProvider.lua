-- Stadium 2 Importer model-ownership provider for Battle Art's voxel scene.
--
-- Replaces the old StadiumBattleFX arena-component registration. That path
-- wedged Battle Art's voxel map into SBFX's *arena slot*, which made SBFX
-- keep drawing its own white UI canvas over our 3D render.
--
-- This provider instead consumes the importer's scene-neutral model API
-- (exports.models apiVersion >= 2): it instantiates independently-owned
-- Stadium Pokemon models and draws them directly into OUR voxel scene's
-- colour/depth target, using our camera, sun shadow map and hour tint. We
-- own the whole frame -- no SBFX presentation layer, therefore no white box.
--
-- Battle Art keeps its own HUD (textbox fills, inverted HUD, the lot); the
-- importer's own HUD layer / DRAW HUD PANELS option is never used.
--
-- Fully fail-safe: when STADIUM2_IMPORTER is absent, or its model API is too
-- old, or STADIUM 2 BATTLE is already owning the scene, this provider does
-- nothing and the ordinary voxel battle (2D cards) draws exactly as before.

local V = ...

local OverworldBattle = V.require("OverworldBattle")

local Provider = {
  registered = false,
  importer = nil,      -- the importer mod handle
  models = nil,        -- exports.models (apiVersion >= 2)
  modRef = nil,
  active = false,      -- a battle with live Stadium instances is staged
  instances = {},      -- { player = instance|nil, enemy = instance|nil }
  flash = { player = false, enemy = false },
}

-- On-device calibration only. World coords here are Battle Art's voxel
-- pixels (one overworld tile ~= CELL). A 7x7 mon covers ~7 tiles. These two
-- constants map a Stadium model's authored height onto that span.
local MON_WORLD_HEIGHT = 96   -- target world-pixel height of a standing mon
local MODEL_YAW_PLAYER = 0    -- rad; player faces +x (toward enemy)
local MODEL_YAW_ENEMY = math.pi

local SUN_DIR = { -0.4, 0.8, 0.25 }

local function findMod(id)
  local finder = V.mod and V.mod.find
  if type(finder) ~= "function" then return nil end
  local ok, handle = pcall(finder, id)
  if ok and handle then return handle end
  ok, handle = pcall(finder, V.mod, id)
  return ok and handle or nil
end

local function shadowMap()
  local ok, ShadowMap = pcall(V.require, "ShadowMap")
  if not ok or type(ShadowMap) ~= "table" then return nil, nil, nil end
  local uvVP = ShadowMap.uvVP
  local res = ShadowMap.res
  local texel = (type(res) == "number" and res > 0)
    and { 1 / res, 1 / res } or { 1 / 1024, 1 / 1024 }
  local map = ShadowMap.map
  return uvVP, map, texel
end

-- Read a dex number (1..251) from a battle mon, supporting both numeric
-- species ids and name keys into the game's pokemon table.
local function dexOf(mon, data)
  if not mon then return nil end
  local s = mon.species
  if type(s) == "number" then
    local d = math.floor(s)
    if d >= 1 and d <= 251 then return d end
    return nil
  end
  if type(s) == "string" and data and data.pokemon then
    local def = data.pokemon[s]
    local d = def and tonumber(def.dex or def.index)
    if d then d = math.floor(d) end
    if d and d >= 1 and d <= 251 then return d end
  end
  return nil
end

local function variantOf(mon)
  if not mon then return "normal" end
  if mon.shiny == true or mon.isShiny == true then return "shiny" end
  return "normal"
end

-- Build player/enemy Stadium instances for the live battle, if the importer
-- can supply them. Returns true when at least one side was created.
function Provider:build(battle)
  if not (self.models and type(self.models.newInstance) == "function") then
    return false
  end
  if type(self.models.apiVersion) ~= "number" or self.models.apiVersion < 2 then
    return false
  end
  -- Only own the scene when the importer is NOT also presenting its own
  -- battle. Leave STADIUM 2 BATTLE on -> the importer owns everything.
  if type(self.importer.battleEnabled) == "function"
      and self.importer.battleEnabled() then return false end
  if type(self.importer.modelsEnabled) == "function"
      and not self.importer.modelsEnabled() then return false end

  self:release()
  local data = battle and battle.data
  local sides = { player = battle and battle.player,
                  enemy = battle and battle.enemy }
  local made = false
  for side, battler in pairs(sides) do
    local mon = battler and battler.mon
    local dex = dexOf(mon, data)
    if dex then
      local instance, err = pcall(self.models.newInstance, dex,
        variantOf(mon), { textureFilter = "nearest", anchorTravel = true })
      if instance and type(instance) == "table" then
        self.instances[side] = instance
        made = true
      elseif V.mod.log and V.mod.log.warn then
        V.mod.log:warn("stadium model %s(%d) unavailable: %s",
          side, dex, tostring(err))
      end
    end
  end
  self.active = made
  return made
end

function Provider:release()
  for side, instance in pairs(self.instances) do
    if instance and type(instance.release) == "function" then
      pcall(instance.release, instance)
    end
    self.instances[side] = nil
  end
  self.active = false
  self.flash.player = false
  self.flash.enemy = false
end

-- The drawActors callback fired by BattleScene.render while our colour/depth
-- target is live. world = { vp, groundY, width, height }.
function Provider:drawActors(world)
  local battle = OverworldBattle.battle()
  if not (battle and self.active) then return end
  local arena = OverworldBattle.arena()
  if not (arena and arena.player and arena.enemy) then return end
  local uvVP, sunMap, sunTexel = shadowMap()
  local tint = Voxel3D and Voxel3D.tint or { 1, 1, 1 }
  local ambient = { tint[1] * 0.5, tint[2] * 0.5, tint[3] * 0.5 }
  local diffuse = { tint[1], tint[2], tint[3] }

  for _, side in ipairs({ "player", "enemy" }) do
    local instance = self.instances[side]
    if instance and type(instance.draw) == "function" then
      local cell = arena[side]
      local groundY = world.groundY or 0
      local position = { cell[1], groundY, cell[2] }
      local yaw = (side == "player") and MODEL_YAW_PLAYER or MODEL_YAW_ENEMY
      -- Fit the model's authored height to MON_WORLD_HEIGHT. metrics() is
      -- caller-safe; fall back to a flat scale when it is unavailable.
      local h = 1
      local ok, m = pcall(instance.metrics, instance)
      if ok and type(m) == "table" and type(m.height) == "number"
          and m.height > 0 then
        h = MON_WORLD_HEIGHT / m.height
      end
      local modelMatrix = {
        h, 0, 0, 0,
        0, h, 0, 0,
        0, 0, h, 0,
        position[1], position[2], position[3], 1,
      }
      -- rotateY(yaw) composes after scale: rebuild with yaw.
      if yaw and yaw ~= 0 then
        local c, s = math.cos(yaw), math.sin(yaw)
        modelMatrix = {
          h * c, 0, h * s, 0,
          0, h, 0, 0,
          -h * s, 0, h * c, 0,
          position[1], position[2], position[3], 1,
        }
      end
      if uvVP and sunMap then
        pcall(instance.drawShadow, instance, {
          modelMatrix = modelMatrix,
          lightViewProjection = uvVP,
        })
      end
      local drawOpts = {
        modelMatrix = modelMatrix,
        camera = { viewProjection = world.vp },
        light = { direction = SUN_DIR, ambient = ambient, diffuse = diffuse },
        shadow = sunMap and {
          map = sunMap, viewProjection = uvVP, texel = sunTexel,
        } or nil,
      }
      if self.flash[side] then
        drawOpts.flashAmount = BattleScene.FLASH_STRENGTH
      end
      pcall(instance.draw, instance, drawOpts)
    end
  end
end

-- True while a Stadium-equipped battle is staged and we should suppress our
-- ordinary 2D cards in favour of the importer models.
function Provider:ownsBattle()
  return self.active
end

-- The drawActors closure BattleScene.render should receive in our own flow.
function Provider:actors()
  if not self.active then return nil end
  return function(world) self:drawActors(world) end
end

function Provider.register()
  if Provider.registered then return true end
  local handle = findMod("STADIUM2_IMPORTER")
  local exports = handle and handle.exports
  local models = exports and exports.models
  if not (models and type(models.apiVersion) == "number"
      and models.apiVersion >= 2) then
    return false
  end
  Provider.importer = exports
  Provider.models = models
  Provider.modRef = handle

  -- Build / tear down Stadium instances around each battle.
  if V.mod and V.mod.events then
    V.mod.events:on("battle.started", function(payload)
      local battle = payload and (payload.battle or payload.game
        and payload.game.save and payload.game.save.battle)
      battle = battle or (payload and payload.battle)
      if battle then Provider:build(battle) end
    end)
    V.mod.events:on("battle.ended", function()
      Provider:release()
    end)
  end

  Provider.registered = true
  if V.mod.log and V.mod.log.info then
    V.mod.log:info("Stadium 2 Importer model provider registered "
      .. "(models apiVersion %d)", models.apiVersion)
  end
  return true
end

return Provider
