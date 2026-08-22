-- Regression for delayed overworld readiness through the public core hook.

local checks = 0

local function check(value, message)
  checks = checks + 1
  if not value then error("FAIL: " .. message, 0) end
end

local function equal(actual, expected, message)
  checks = checks + 1
  if actual ~= expected then
    error(("FAIL: %s (expected %s, got %s)")
      :format(message, tostring(expected), tostring(actual)), 0)
  end
end

local Lifecycle = assert(loadfile("lib/CompanionLifecycle.lua"))()

local wrappedName, wrapped
local messages = {}
local mod = {
  hooks = {
    wrap = function(_, name, callback)
      wrappedName, wrapped = name, callback
      return function() end
    end,
  },
  log = {
    error = function(_, format, value)
      messages[#messages + 1] = tostring(format):format(value)
    end,
  },
}

local calls = {}
local companion = {
  updateFromGame = function(_, dt, game)
    calls[#calls + 1] = { dt = dt, game = game, ready = game.overworld ~= nil }
  end,
}

check(type(Lifecycle.install(mod, companion)) == "function",
  "install returns the public hook removal handle")
equal(wrappedName, "core.update", "lifecycle binds only to public core.update")

local game = {}
local order = {}
local first, second = wrapped(function(actualGame, dt)
  order[#order + 1] = "engine"
  equal(actualGame, game, "the engine receives the public game object")
  equal(dt, 0.016, "the engine receives the original delta")
  return "engine-result", nil
end, game, 0.016)
order[#order + 1] = "returned"

equal(first, "engine-result", "the hook preserves the engine return value")
equal(second, nil, "the hook preserves trailing nil return values")
equal(calls[1].game, game, "the adapter receives the same public game object")
equal(calls[1].ready, false, "startup can run before an overworld exists")
equal(order[1], "engine", "the engine update runs before companion observation")

game.overworld = { map = { id = "PALLET_TOWN" } }
wrapped(function() order[#order + 1] = "engine-ready" end, game, 0.016)
equal(calls[2].ready, true,
  "a later core update exposes the ready overworld to the adapter")

companion.updateFromGame = function() error("synthetic lifecycle fault", 0) end
wrapped(function() end, game, 0.016)
wrapped(function() end, game, 0.016)
equal(#messages, 1, "a repeated lifecycle fault is logged once")

io.write(('%d checks passed (Voxel Companion core lifecycle)\n'):format(checks))
