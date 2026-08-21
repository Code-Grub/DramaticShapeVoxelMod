-- Optional StadiumBattleFX Battle Presentation API v1 components.
-- Registration is inert when SBFX is absent. The arena, native card models,
-- and placed Battle Art camera are independently selectable in SBFX.

local V = ...
local OverworldBattle = V.require("OverworldBattle")

local Provider = { registered = false, fallback = nil, ids = {} }
local Camera = {}
local Models = {}
local Hud = {}
local Transitions = {}
local available

local function selected(api, slot, id)
  if not (api and type(api.isSelected) == "function") then return false end
  local ok, value = pcall(api.isSelected, api, slot, id)
  return ok and value == true
end

local function findMod(id)
  local finder = V.mod and V.mod.find
  if type(finder) ~= "function" then return nil end
  local ok, handle = pcall(finder, id)
  if ok and handle then return handle end
  ok, handle = pcall(finder, V.mod, id)
  return ok and handle or nil
end

function Provider:arena(context)
  if not available(context) then
    return self.fallback
  end
  return OverworldBattle.arena()
end

function Provider:begin(context)
  if not available(context) then return self.fallback end
  return OverworldBattle.providerBegin(context and context.battle)
    or self.fallback
end

function Provider:render(context, arena, drawActors)
  local useNativeCards = selected(self.api, "models", self.ids.models)
  local useNativeHud = selected(self.api, "hud", self.ids.hud)
  local canvas = OverworldBattle.providerRender(
    context and context.battle, useNativeCards and nil or drawActors,
    context and context.services and context.services.camera
    and context.services.camera.pose, useNativeCards, useNativeHud)
  return canvas or self.fallback
end

function Provider:update(context, dt)
  -- OverworldBattle's pipeline tick owns camera/input/mesh progression. The
  -- sole API-owned update is Battle Art's optional animated card/trainer art,
  -- and only when its model provider is explicitly selected.
  OverworldBattle.providerUpdate(context and context.battle, dt,
    selected(self.api, "models", self.ids.models))
end

function Transitions:begin(context)
  return available(context) and true or Provider.fallback
end

function Provider:finish()
  OverworldBattle.providerFinish()
end

function Provider:invalidate()
  OverworldBattle.providerInvalidate()
end

function Camera:claim(context)
  return OverworldBattle.providerAvailable(context and context.battle)
end

function Camera:shot(context)
  return OverworldBattle.providerCamera(context and context.battle)
end

-- Battle Art's cards are drawn within its advanced arena pass so they share
-- its terrain depth buffer and card-shadow path. The host still dispatches
-- drawWorld, but it is intentionally a no-op: Provider:render selects the
-- native card path before that callback is reached.
function Models:begin(context)
  if not OverworldBattle.providerAvailable(context and context.battle) then
    return Provider.fallback
  end
  return true
end

function Models:covers(context, side)
  return (side == "player" or side == "enemy")
    and OverworldBattle.providerHosted(context and context.battle)
end

function Models:update()
end

function Models:invalidate()
end

function Models:cameraLocked(context)
  -- BACK SPRITES is a mixed 2D/world composition. A directed camera would
  -- move the voxel opponent while the player's card remains pinned to the
  -- native menu, so preserve Battle Art's authored base pose.
  return OverworldBattle.backPinned()
end

function Models:showing(context, side)
  return OverworldBattle.providerModelShowing(context and context.battle, side)
end

function Models:center(context, side)
  return OverworldBattle.providerModelPoint(context and context.battle, side)
end

function Models:footprint(context, side)
  return OverworldBattle.providerModelFootprint(context and context.battle, side)
end

function Models:attachment(context, side, tag)
  if tag == 0xFF or tag == 0x64 then
    return self:center(context, side)
  end
  return nil
end

function Models:attachmentTags()
  return 0x64, 0xFF
end

function Models:drawWorld()
end

-- Battle Art renders this HUD inside the arena canvas so its projected bands
-- share the map's perspective and stay out of the native 160x144 field.  The
-- provider's render pass does the drawing; this component owns selection and
-- the host-side lifecycle boundary.
function Hud:begin(context)
  return available(context) and true or Provider.fallback
end

function Hud:drawScreen()
end

local function arenaSelected()
  return selected(Provider.api, "arena", Provider.ids.arena)
end

available = function(context)
  return OverworldBattle.sbfxEnabled()
    and OverworldBattle.providerAvailable(context and context.battle)
end

function Provider.register()
  if Provider.registered then return true end
  local handle = findMod("STADIUM_BATTLE_FX")
  local api = handle and handle.exports and handle.exports.battles
  if not (api and api.version == 1
      and type(api.registerComponent) == "function") then return false end
  Provider.api = api
  Provider.fallback = api.FALLBACK
  local ok, id = pcall(api.registerComponent, api, V.mod.id, "arena",
    "voxel-map", {
      label = "BATTLE ART VOXEL MAP",
      description = "Battle Art's staged voxel-map arena; models and other "
        .. "features remain independently selectable.",
      provider = Provider,
      available = available,
    })
  if not ok then
    if V.mod.log and V.mod.log.warn then
      V.mod.log:warn("StadiumBattleFX arena registration failed: %s", tostring(id))
    end
    return false
  end
  Provider.ids.arena = id
  ok, id = pcall(api.registerComponent, api, V.mod.id, "models",
    "native-cards", {
      label = "BATTLE ART NATIVE CARDS",
      description = "Battle Art's selected static or animated battle cards "
        .. "inside its voxel-map arena.",
      provider = Models,
      available = function(context)
        return available(context) and arenaSelected()
      end,
    })
  if not ok then
    if V.mod.log and V.mod.log.warn then
      V.mod.log:warn("StadiumBattleFX model registration failed: %s", tostring(id))
    end
    return false
  end
  Provider.ids.models = id
  ok, id = pcall(api.registerComponent, api, V.mod.id, "camera",
    "placed-camera", {
      label = "BATTLE ART PLACED CAMERA",
      description = "Battle Art's over-the-shoulder voxel-map battle camera.",
      provider = Camera,
      available = function(context)
        return available(context) and arenaSelected()
      end,
    })
  if not ok then
    if V.mod.log and V.mod.log.warn then
      V.mod.log:warn("StadiumBattleFX camera registration failed: %s", tostring(id))
    end
    return false
  end
  Provider.ids.camera = id
  ok, id = pcall(api.registerComponent, api, V.mod.id, "hud",
    "projected-hud", {
      label = "BATTLE ART PROJECTED HUD",
      description = "Battle Art's projected HUD bands. HUD SCALE continues to "
        .. "control their size.",
      provider = Hud,
      available = function(context)
        return available(context) and arenaSelected()
      end,
    })
  if not ok then
    if V.mod.log and V.mod.log.warn then
      V.mod.log:warn("StadiumBattleFX HUD registration failed: %s", tostring(id))
    end
    return false
  end
  Provider.ids.hud = id
  ok, id = pcall(api.registerComponent, api, V.mod.id, "transitions",
    "exit-fade", {
      label = "BATTLE ART EXIT FADE",
      description = "Battle Art's voxel battle exit fade. Select OFF or another "
        .. "provider to use its transition instead.",
      provider = Transitions,
      available = function(context)
        return available(context) and arenaSelected()
      end,
    })
  if not ok then
    if V.mod.log and V.mod.log.warn then
      V.mod.log:warn("StadiumBattleFX transition registration failed: %s", tostring(id))
    end
    return false
  end
  Provider.ids.transitions = id
  Provider.registered = true
  Provider.id = Provider.ids.arena
  OverworldBattle.configureSbfx(api, Provider.ids.arena, Provider.ids.transitions,
    Provider.ids.hud)
  return true
end

return Provider
