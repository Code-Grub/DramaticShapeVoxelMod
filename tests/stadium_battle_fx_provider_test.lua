-- Standalone contract test for optional StadiumBattleFX arena registration.
local expectedOwner = "BATTLE_ART_VOXEL_FORK"
local fallback = {}
local registered = {}
local calls = {}
local OverworldBattle = {
  providerAvailable = function(battle)
    calls.available = battle
    return battle == "battle"
  end,
  arena = function() return { id = "map-arena" } end,
  providerBegin = function(battle)
    calls.begin = battle
    return battle == "battle"
  end,
  providerRender = function(battle, drawActors)
    calls.render = battle
    if drawActors then
      drawActors({ vp = {}, groundY = 7, width = 160, height = 144 })
    end
    return "canvas"
  end,
  providerFinish = function() calls.finished = true end,
  providerInvalidate = function() calls.invalidated = true end,
  providerHosted = function() return true end,
  providerCamera = function() return { eye = { 1, 2, 3 }, focus = { 0, 0, 0 }, fov = 1 }, 0.5 end,
  providerModelShowing = function(_, side) return side == "player" end,
  providerModelPoint = function(_, side) return side == "player" and 22 or 33, 44 end,
  providerModelFootprint = function(_, side) return side == "player" and 8 or 9 end,
  providerUpdate = function(battle, dt, native)
    calls.updateBattle, calls.updateDt, calls.updateNative = battle, dt, native
  end,
  sbfxEnabled = function() return true end,
  backPinned = function() return true end,
  configureSbfx = function(api, arenaId, transitionId, hudId)
    calls.configuredApi, calls.configuredArena, calls.configuredTransition, calls.configuredHud = api, arenaId, transitionId, hudId
    return true
  end,
}
local api = {
  version = 1,
  FALLBACK = fallback,
  isSelected = function(_, slot, id)
    return (slot == "arena" and id == expectedOwner .. ":voxel-map")
      or (slot == "models" and id == expectedOwner .. ":native-cards")
      or (slot == "hud" and id == expectedOwner .. ":projected-hud")
  end,
  registerComponent = function(_, owner, slot, id, definition)
    registered[slot] = { owner, slot, id, definition }
    return owner .. ":" .. id
  end,
}
local V = {
  mod = {
    id = expectedOwner,
    find = function(id)
      if id == "STADIUM_BATTLE_FX" then
        return { exports = { battles = api } }
      end
    end,
    log = { warn = function() error("registration should not warn") end },
  },
  require = function(name)
    assert(name == "OverworldBattle")
    return OverworldBattle
  end,
}

for _, path in ipairs({
  "lib/BattleScene.lua",
  "lib/OverworldBattle.lua",
  "lib/StadiumBattleFxProvider.lua",
  "main.lua",
}) do
  assert(loadfile(path), path .. " must compile")
end

local Provider = assert(loadfile("lib/StadiumBattleFxProvider.lua"))(V)
assert(Provider.register() == true)
assert(Provider.register() == true, "registration must be idempotent")
local arenaRegistration = registered.arena
assert(arenaRegistration[1] == expectedOwner and arenaRegistration[2] == "arena"
  and arenaRegistration[3] == "voxel-map")
local definition = arenaRegistration[4]
assert(definition.available({ battle = "battle" }) == true)
assert(definition.available({ battle = "other" }) == false)
assert(definition.provider == Provider)
assert(registered.models[3] == "native-cards")
assert(registered.camera[3] == "placed-camera")
assert(registered.hud[3] == "projected-hud")
assert(registered.transitions[3] == "exit-fade")
assert(calls.configuredApi == api
  and calls.configuredArena == expectedOwner .. ":voxel-map")
assert(calls.configuredTransition == expectedOwner .. ":exit-fade")
assert(calls.configuredHud == expectedOwner .. ":projected-hud")
assert(registered.models[4].available({ battle = "battle" }) == true)
assert(registered.camera[4].available({ battle = "battle" }) == true)
assert(registered.hud[4].available({ battle = "battle" }) == true)
assert(registered.transitions[4].available({ battle = "battle" }) == true)
assert(Provider:arena({ battle = "other" }) == fallback)
assert(Provider:arena({ battle = "battle" }).id == "map-arena")
assert(Provider:begin({ battle = "battle" }) == true)
Provider:update({ battle = "battle" }, 0.25)
assert(calls.updateBattle == "battle" and calls.updateDt == 0.25
  and calls.updateNative == true)
local drew
assert(Provider:render({ battle = "battle" }, {}, function(world)
  drew = world.groundY == 7 and world.width == 160 and world.height == 144
end) == "canvas")
assert(drew == true and calls.render == "battle")
local models = registered.models[4].provider
assert(models:showing({ battle = "battle" }, "player") == true)
assert(models:center({ battle = "battle" }, "player") == 22)
assert(models:footprint({ battle = "battle" }, "player") == 8)
assert(models:cameraLocked({ battle = "battle" }) == true)
assert(models:attachmentTags({}) == 0x64)
local hud = registered.hud[4].provider
assert(hud:begin({ battle = "battle" }) == true)
assert(hud:begin({ battle = "other" }) == fallback)
Provider:invalidate()
assert(calls.invalidated == true)
Provider:finish()
assert(calls.finished == true)
print("ok StadiumBattleFX voxel-map arena provider " .. expectedOwner)
