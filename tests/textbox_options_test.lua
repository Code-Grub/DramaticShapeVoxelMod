local settings = {}

local ModSetting = {}
function ModSetting.new(key, label, values, labels, defaultIndex)
  local setting = {
    key = key,
    label = label,
    values = values,
    labels = labels,
    value = values[defaultIndex or 1],
  }
  function setting:get() return self.value end
  function setting:sync(value) self.value = value end
  settings[key] = setting
  return setting
end

local V = {
  require = function(name)
    if name == "ModSetting" then return ModSetting end
    error("unexpected module " .. tostring(name))
  end,
}

local root = MOD_ROOT or "."
local UiBackplates = assert(loadfile(root .. "/lib/UiBackplates.lua"))(V)

local function eq(actual, expected, label)
  if actual ~= expected then
    error(("%s: expected %s, got %s"):format(
      label, tostring(expected), tostring(actual)), 0)
  end
end

eq(settings.textboxFill ~= nil, true, "TEXTBOX FILL setting exists")
eq(settings.hudColor ~= nil, true, "HUD COLOR setting exists")
eq(settings.hudColor:get(), "COLOR", "HUD COLOR defaults to original colours")
eq(UiBackplates.hudUsesColor(), true, "fresh installs preserve coloured HUDs")
eq(UiBackplates.hudUsesColorShadow(), true,
  "COLOR uses its terrain contrast shadow")
settings.hudColor:sync("INVERTED")
eq(UiBackplates.hudUsesColor(), false, "INVERTED selects white HUD ink")
eq(UiBackplates.hudUsesColorShadow(), false,
  "INVERTED does not use COLOR's gray shadow")
settings.hudColor:sync("COLOR")
eq(UiBackplates.textboxMode(), "WHITE", "latest-compatible default is WHITE")

settings.textboxFill:sync("HALF")
eq(UiBackplates.textboxMode(), "HALF", "HALF is selectable")
local half = UiBackplates.textboxFillStyle()
eq(half[1], 0, "HALF is black")
eq(half[4], 0.30, "HALF uses the requested translucency")

settings.textboxFill:sync("BLACK")
local black = UiBackplates.textboxFillStyle()
eq(black[1], 0, "BLACK is black")
eq(black[4], 1, "BLACK is opaque")

settings.textboxFill:sync("OFF")
eq(UiBackplates.textboxFillStyle(), nil, "OFF has no paper fill")

settings.textboxFill:sync("HALF")
settings.arenaFill:sync("WHITE")
eq(UiBackplates.textboxMode(), "WHITE",
  "ARENA FILL WHITE preserves the official readable white textbox")
settings.hudColor:sync("INVERTED")
eq(UiBackplates.hudUsesColor(), true,
  "ARENA FILL WHITE forces black and coloured HUD rendering")
eq(UiBackplates.hudUsesColorShadow(), false,
  "the solid white arena does not add COLOR's gray terrain shadow")

print("textbox_options_test: PASS")
