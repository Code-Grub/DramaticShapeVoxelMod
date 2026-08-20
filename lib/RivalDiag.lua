-- Rival sprite diagnostic logger.
--
-- Battle Art never redefines the OPP_RIVAL1/2/3 trainer records or their pics;
-- it only sets the runtime battle.trainerPic field via replaceTrainerField.
-- When a rival's sprite does not show during actual play, this module captures
-- the decisive values to a file so the gap is visible instead of silent.
--
-- Writes to a plain file through love.filesystem when the engine exposes it
-- (legacy Android 0.1.83 -- the primary on-device test target, where FS is
-- writable). On sandboxed 0.2.7 builds where love.filesystem is hidden, it
-- falls back to mod.storage (the same backend the mesh cache uses). Every call
-- is pcall-guarded: a missing backend simply means no log, never a crash.

local V = ...

local RivalDiag = {}

local LOG_NAME = "battle_art_rival_diag.log"
local STORAGE_KEY = "battle_art_rival_diag"

-- cap the file so a long session cannot grow it without bound
local MAX_LINES = 2000

local function stamp()
  local ok, t = pcall(os.time)
  return ok and tostring(t) or "?"
end

local function appendLine(line)
  line = "[" .. stamp() .. "] " .. line
  -- legacy / writable FS path
  local ok, fs = pcall(function() return love and love.filesystem end)
  if ok and fs and fs.append and fs.getInfo then
    pcall(fs.append, LOG_NAME, line .. "\n")
    return
  end
  -- sandboxed storage fallback (key-value; keep a bounded ring in one value)
  local okS, storage = pcall(function()
    return V and V.mod and V.mod.storage
  end)
  if okS and storage and storage.get and storage.set then
    pcall(function()
      local prev = storage.get(STORAGE_KEY) or ""
      local lines = {}
      for s in tostring(prev):gmatch("[^\n]+") do lines[#lines + 1] = s end
      lines[#lines + 1] = line
      while #lines > MAX_LINES do table.remove(lines, 1) end
      storage.set(STORAGE_KEY, table.concat(lines, "\n"))
    end)
  end
end

-- Log one diagnostic line. `tag` groups the event; the rest are key/value
-- pairs. Designed to be called liberally -- it never throws.
function RivalDiag.log(tag, ...)
  local parts = { tag }
  local n = select("#", ...)
  for i = 1, n do
    local v = select(i, ...)
    if v == nil then parts[#parts + 1] = "nil"
    else parts[#parts + 1] = tostring(v) end
  end
  appendLine(table.concat(parts, " | "))
end

return RivalDiag
