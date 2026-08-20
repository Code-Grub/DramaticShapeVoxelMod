-- Interface sprites: show BATTLE ART's selected-generation FRONT in the
-- non-battle interfaces (title screen, Pokedex, status/party, hall of fame),
-- toggleable independently of DUPLICATE FIX (which only owns battle pictures).
--
-- Implementation note -- this does NOT mutate the pokemon data table. The
-- engine resolves every pokemon picture through the `pokemon.sprite` hook,
-- passing a ctx that says what it is resolving (ctx.kind / ctx.side). We wrap
-- that single seam and, for interface (non-battle) contexts, answer with our
-- selected-generation front path. Because we read the option live on every
-- call, the toggle needs no restart and no data-record capture/restore.
--
-- Front-only by owner decision: the interfaces show our chosen front and
-- never a back. Battles keep their own (separate) logic in main.lua's
-- pokemon.sprite wrap (player back -> front substitution).

local V = ...

local ModSetting = V.require("ModSetting")
local BattleArt = V.require("BattleArt")

local InterfaceSprites = {}

-- OFF       : leave interface sprites to the engine / other mods (e.g. ROM).
-- BATTLE ART : install our selected-generation front in every interface.
-- MODDED    : identical to OFF here -- another sprite mod or the ROM owns it.
InterfaceSprites.setting = ModSetting.new("interfaceSprites",
  "INTERFACE SPRITES",
  { "off", "battle_art", "modded" },
  { "OFF", "BATTLE ART", "MODDED" }, 1)

local function active()
  return InterfaceSprites.setting:get() == "battle_art"
     and BattleArt.ownsSpeciesArt()
end

-- Build our front path for a species, or nil to fall back to the engine/ROM.
--
-- Rules (owner):
--  * regular form only -- never the shiny child (no DV/shiny check for
--    interfaces); if there is no species sprite at all, use ROM.
--  * STATIC mode  -> front-static/<slug>.png (generation-neutral).
--  * ANIMATED mode -> front-animated/<gen>/<slug>.png (the generation atlas;
--    returning the raw path lets the engine play the sprite atlas animation).
--  * ROM mode or a missing file -> nil, so the engine's own (ROM) art shows.
local function ourFront(ctx)
  if not active() then return nil end
  -- The species can arrive in several shapes depending on caller (battle ctx,
  -- title ctx, dex ctx). Accept the common fields.
  local species = (ctx and (ctx.species
                  or (ctx.mon and ctx.mon.species)
                  or (ctx.data and ctx.data.species))) or nil
  if not species then return nil end
  local mode = BattleArt.setting:get()
  if mode == "rom" then return nil end
  local rel
  if mode == "static" then
    rel = BattleArt.staticSpeciesRelativePath(species, "front", false)
  else
    -- ANIMATED (or any other non-rom mode): generation atlas, regular form.
    local gen = BattleArt.frontAnimationSetting:get()
    rel = BattleArt.generationRelativePath(species, gen, "front", false)
  end
  if not rel then return nil end
  return V.mod.assets:path(rel)
end

-- Register the pokemon.sprite seam. Called from main.lua after the module is
-- required, so V.mod (and its hooks table) is fully populated.
function InterfaceSprites.install()
  -- The seam. next() first so any sprite-replacing mod loaded before us still
  -- gets the last word on WHICH art; we only change interface fronts.
  V.mod.hooks:wrap("pokemon.sprite", function(next, path, ctx)
    local out = next(path, ctx)
    -- Battles are handled by main.lua's own wrap (player back -> front).
    -- Leave every battle picture strictly alone here.
    if ctx and ctx.kind == "battle" then return out end
    -- Only a BACK slot must keep the engine's back sprite (the left card on
    -- the status/summary screen). Every other slot -- front, nil side, or the
    -- title screen's cycling mon (which passes a non-"front" side) -- gets our
    -- front. Blocking on side ~= "front" here was wrongly excluding the title.
    if ctx.side == "back" then return out end
    -- Substitute our front for interface contexts (title, dex, summary,
    -- party, hall of fame, trainer card) when active.
    local front = ourFront(ctx)
    return front or out
  end)

  installSummary()
end

-- The status/summary HP bar is drawn by the engine's native SummaryMenu.draw
-- on the fixed 160x144 virtual canvas (scaled to the window, so coordinates
-- here are resolution- and aspect-ratio-independent). The engine's bar shows
-- as a black track at full HP; we redraw it with the standard green/yellow/
-- red ramp (green >50%, yellow 20-50% -- the Super Fang danger band -- red
-- <20%) on the STATUS page (page 1), replacing the engine's track in place.
local function hpColor(ratio)
  if ratio <= 0.2 then return 0.85, 0.13, 0.09   -- red
  elseif ratio <= 0.5 then return 0.95, 0.70, 0.05 -- yellow
  end
  return 0.20, 0.85, 0.28                         -- green
end

-- Canonical Gen1 status-page HP gauge rectangle, in 160x144 canvas space.
local HP_X, HP_Y, HP_W, HP_H = 88, 17, 64, 4

function InterfaceSprites.installSummary()
  local ok, SummaryMenu = pcall(require, "src.ui.SummaryMenu")
  if not (ok and SummaryMenu and SummaryMenu.draw) then return end
  local originalDraw = SummaryMenu.draw
  SummaryMenu.draw = function(self)
    originalDraw(self)
    if not active() then return end
    if not (self and self.mon and self.page == 1) then return end
    local mon = self.mon
    local maxhp = tonumber(mon.maxHp)
        or (mon.stats and tonumber(mon.stats.hp)) or 0
    local hp = tonumber(mon.hp) or 0
    if maxhp <= 0 then return end
    local ratio = math.max(0, math.min(1, hp / maxhp))
    local r, g, b = hpColor(ratio)
    -- Clear the engine's black track, then draw a clean gauge over it.
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", HP_X - 1, HP_Y - 1, HP_W + 2, HP_H + 2)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", HP_X, HP_Y, HP_W, HP_H)
    love.graphics.setColor(r, g, b, 1)
    love.graphics.rectangle("fill", HP_X, HP_Y, math.max(1, HP_W * ratio), HP_H)
    love.graphics.setColor(1, 1, 1, 1)
  end
end

return InterfaceSprites
