-- Battle Art ARENA FILL provider for Stadium 2 Importer's owned battle scene.
-- The importer retains its camera, platforms, models and HUD; this module
-- replaces only its public background phase.

local V = ...

local UiBackplates = V.require("UiBackplates")
local Gen6Backdrop = V.require("Gen6Backdrop")
local BossBackdrop = V.require("BossBackdrop")
local Images = V.require("BackdropImage")
local Voxel3D = V.require("Voxel3D")
local OverworldBattle = V.require("OverworldBattle")

local StadiumBackground = {}
local installed = false
local hostedBattle
local catcherMesh
local catcherShader

local CATCHER_SHADER = [[
varying vec3 vSun;
#ifdef VERTEX
uniform mat4 mvp;
uniform mat4 sunVP;
vec4 position(mat4 transform_projection, vec4 vertex_position) {
  vSun = (sunVP * vertex_position).xyz;
  return mvp * vertex_position;
}
#endif
#ifdef PIXEL
uniform Image sunMap;
uniform float sunDark;
uniform float sunBias;
uniform vec2 sunTexel;
float depthAt(vec2 uv) {
  vec4 c = Texel(sunMap, uv);
  return c.r + c.g / 255.0;
}
vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
  if (vSun.x < 0.0 || vSun.x > 1.0 || vSun.y < 0.0 || vSun.y > 1.0
      || vSun.z > 1.0) discard;
  float z = vSun.z - sunBias;
  float lit = step(z, depthAt(vSun.xy + sunTexel * vec2(-1.5, -0.5)))
            + step(z, depthAt(vSun.xy + sunTexel * vec2( 0.5, -1.5)))
            + step(z, depthAt(vSun.xy + sunTexel * vec2( 1.5,  0.5)))
            + step(z, depthAt(vSun.xy + sunTexel * vec2(-0.5,  1.5)));
  float alpha = sunDark * (1.0 - lit * 0.25);
  if (alpha <= 0.005) discard;
  return vec4(0.015, 0.018, 0.025, alpha);
}
#endif
]]

local function shadowCatcherAssets(g)
  if catcherMesh == false or catcherShader == false then return nil end
  if not catcherMesh then
    local format = {
      { "VertexPosition", "float", 3 },
      { "VertexTexCoord", "float", 2 },
    }
    local vertices = {
      { -64, -0.08, -64, 0, 0 }, { 64, -0.08, -64, 1, 0 },
      { 64, -0.08, 64, 1, 1 }, { -64, -0.08, 64, 0, 1 },
    }
    local ok, mesh = pcall(g.newMesh, format, vertices, "fan", "static")
    catcherMesh = ok and mesh or false
  end
  if not catcherShader then
    local ok, shader = pcall(g.newShader, CATCHER_SHADER)
    catcherShader = ok and shader or false
  end
  return catcherMesh and catcherShader and true or nil
end

local function drawShadowCatcher(ctx)
  local g = ctx and ctx.graphics
  local camera = ctx and ctx.camera
  local shadow = ctx and ctx.shadow
  local vp = camera and (camera.vp or camera.viewProjection)
  if not (g and g.newMesh and g.newShader and vp and shadow and shadow.map
      and shadow.sunVP and shadowCatcherAssets(g)) then return false end
  if g.setShader then g.setShader(catcherShader) end
  if g.setMeshCullMode then g.setMeshCullMode("none") end
  if g.setDepthMode then g.setDepthMode("lequal", false) end
  if g.setBlendMode then g.setBlendMode("alpha", "alphamultiply") end
  if g.setColor then g.setColor(1, 1, 1, 1) end
  pcall(catcherShader.send, catcherShader, "mvp", "row", vp)
  pcall(catcherShader.send, catcherShader, "sunVP", "row", shadow.sunVP)
  pcall(catcherShader.send, catcherShader, "sunMap", shadow.map)
  pcall(catcherShader.send, catcherShader, "sunDark",
    tonumber(shadow.sunDark) or 0.55)
  pcall(catcherShader.send, catcherShader, "sunBias",
    tonumber(shadow.sunBias) or 0.003)
  pcall(catcherShader.send, catcherShader, "sunTexel",
    shadow.sunTexel or { 1 / 1024, 1 / 1024 })
  local ok = pcall(g.draw, catcherMesh)
  if g.setShader then g.setShader() end
  if g.setDepthMode then g.setDepthMode() end
  if g.setBlendMode then g.setBlendMode("alpha", "alphamultiply") end
  if g.setColor then g.setColor(1, 1, 1, 1) end
  return ok
end

local function findMod(id)
  local finder = V.mod and V.mod.find
  if type(finder) ~= "function" then return nil end
  local ok, handle = pcall(finder, id)
  if ok and handle then return handle end
  ok, handle = pcall(finder, V.mod, id)
  return ok and handle or nil
end

local function battleMap(ctx)
  local map = OverworldBattle.map and OverworldBattle.map() or nil
  if map then return map end
  local game = ctx and ctx.scene and ctx.scene.game
  return game and game.overworld and game.overworld.map or nil
end

local function selectedImage(map, battle)
  local boss = UiBackplates.arenaArt() and UiBackplates.bossEnabled()
    and BossBackdrop.image(map, battle) or nil
  if boss then return boss end
  if UiBackplates.arenaPng() then return Images.load("bosses", "arena.png") end
  if UiBackplates.arenaGen6() then return Gen6Backdrop.image(map, battle) end
  return nil
end

local function drawImage(g, image, width, height)
  if not (g and image and image.getDimensions and width and height) then
    return false
  end
  local ok, iw, ih = pcall(image.getDimensions, image)
  if not ok then return false end
  local x, y, scale = Voxel3D.coverRect(iw, ih, width, height,
    UiBackplates.backdropOffsetPixels())
  if not scale then return false end

  local blur = Voxel3D.backdropShader()
  if g.setShader then g.setShader(blur) end
  if blur then
    pcall(blur.send, blur, "texel", { 1 / iw, 1 / ih })
    pcall(blur.send, blur, "radius", Voxel3D.BACKDROP_BLUR_RADIUS)
  end
  if g.setDepthMode then g.setDepthMode("always", false) end
  if g.setBlendMode then g.setBlendMode("alpha", "alphamultiply") end
  if g.setColor then g.setColor(1, 1, 1, 1) end
  local dx, dy, sx, sy = Voxel3D.backdropTransform(iw, ih, x, y, scale,
    Voxel3D.metalRenderer())
  g.draw(image, dx, dy, 0, sx, sy)
  return true
end

function StadiumBackground.draw(next, ctx)
  local mode = UiBackplates.arenaFill:get()
  if mode == "OFF" or mode == "BLUE" then return next(ctx) end

  local g = ctx and ctx.graphics
  local target = ctx and ctx.target
  if not (g and target) then return next(ctx) end
  if mode == "WHITE" then
    g.clear(1, 1, 1, 1, true, true)
    return true
  end

  local battle = ctx.scene and ctx.scene.battle or OverworldBattle.battle()
  local image = selectedImage(battleMap(ctx), battle)
  if not image then return next(ctx) end
  g.clear(0, 0, 0, 1, true, true)
  if drawImage(g, image, target.width, target.height) then return true end
  return next(ctx)
end

local function releaseVoxelHost()
  if not hostedBattle then return end
  OverworldBattle.providerFinish()
  hostedBattle = nil
end

local function bindTarget(g, target)
  if not (g and g.setCanvas and target and target.color) then return true end
  local binding = target.depth
    and { target.color, depthstencil = target.depth }
    or { target.color, depth = true }
  return pcall(g.setCanvas, binding)
end

local function drawCanvas(g, canvas, target)
  if not (canvas and canvas.getDimensions and g and g.draw) then return false end
  local ok, cw, ch = pcall(canvas.getDimensions, canvas)
  if not ok or not (cw and ch and cw > 0 and ch > 0) then return false end
  if not bindTarget(g, target) then return false end
  if g.setShader then g.setShader() end
  if g.setDepthMode then g.setDepthMode("always", false) end
  if g.setBlendMode then g.setBlendMode("alpha", "alphamultiply") end
  if g.setColor then g.setColor(1, 1, 1, 1) end
  g.draw(canvas, 0, 0, 0, target.width / cw, target.height / ch)
  return true
end

local function drawCircleStage(next, ctx)
  local scale = UiBackplates.stadiumCircleScale()
  if scale <= 0 then return ctx and ctx.marks or next(ctx) end
  if scale >= 1 then return next(ctx) end

  -- Scene API v1 exposes the concrete host. Current Stadium importers publish
  -- their Stage helper on that host; scope the radius override to this one
  -- synchronous fallback call and restore it even if drawing fails.
  local host = ctx and ctx.scene and ctx.scene.host
  local stage = host and host.Stage
  local radius = stage and stage.radius
  if type(radius) ~= "function" then return next(ctx) end
  stage.radius = function(actor) return radius(actor) * scale end
  local ok, a, b = pcall(next, ctx)
  stage.radius = radius
  if not ok then error(a, 0) end
  return a, b
end

local function stadiumActorPasses()
  -- Stadium draws its models after this environment canvas. Their completed
  -- shadow map is supplied separately as the voxel receiver's second sun.
  return { draw = function() return true end }
end

-- OFF means the real Battle Art level, not Stadium's generic platforms. The
-- existing BattleStage hosting seam renders terrain without sprite cards; the
-- importer then draws its own models and HUD over that completed environment.
function StadiumBackground.environment(next, ctx)
  local mode = UiBackplates.arenaFill:get()
  if mode ~= "OFF" then
    releaseVoxelHost()
    local result = drawCircleStage(next, ctx)
    -- A flat plate has no geometry to receive the already-completed Stadium
    -- model shadow map. When its visible circle is hidden or reduced, draw
    -- only those shadow texels onto an invisible arena-local ground plane.
    -- The catcher sits just below the real platform and does not write depth,
    -- so HALF keeps the platform's normal shadow inside its edge while the
    -- catcher supplies only the otherwise-clipped continuation beyond it.
    if UiBackplates.stadiumCircleScale() < 1 then drawShadowCatcher(ctx) end
    return result
  end
  local battle = ctx and ctx.scene and ctx.scene.battle
  local g, target = ctx and ctx.graphics, ctx and ctx.target
  if not (battle and g and target) then return drawCircleStage(next, ctx) end
  if hostedBattle ~= battle then
    releaseVoxelHost()
    if not OverworldBattle.providerBegin(battle) then
      return drawCircleStage(next, ctx)
    end
    hostedBattle = battle
  end
  local canvas = OverworldBattle.providerRender(battle,
    stadiumActorPasses(ctx), ctx.camera, ctx.shadow)
  if not drawCanvas(g, canvas, target) then
    releaseVoxelHost()
    return drawCircleStage(next, ctx)
  end
  -- The optional platform is drawn after the opaque voxel canvas, so ON/HALF
  -- stays visible while OFF leaves only the terrain and its model shadows.
  return drawCircleStage(next, ctx)
end

function StadiumBackground.install()
  if installed then return true end
  local handle = findMod("STADIUM2_IMPORTER")
  local scene = handle and handle.exports and handle.exports.scene
  if not (scene and tonumber(scene.VERSION or scene.apiVersion) == 1
      and type(scene.register) == "function") then return false end
  local okBackground = pcall(scene.register, V.mod, "background",
    StadiumBackground.draw, 100)
  local okEnvironment = pcall(scene.register, V.mod, "environment",
    StadiumBackground.environment, 100)
  installed = okBackground and okEnvironment
  if installed and V.mod.events and type(V.mod.events.on) == "function" then
    V.mod.events:on("battle.ended", releaseVoxelHost)
  end
  return installed
end

function StadiumBackground.installed()
  return installed
end

return StadiumBackground
