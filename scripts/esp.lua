-- esp.lua V70
log("V70 sw="..sw().." sh="..sh())

local ok = false
local n = 0
local arr = 0
local hArr = 0
local objP = 0
local hP = 0
local camE = 0
local hCam = 0
local frame = 0
local ticks = 0
local lastTry = -999
local mFOT, mGP, mGT

local function boot_cfg()
  if ticks < 60 then return false end
  if cfg("set.reset") == 1 then
    setcfg("set.reset", 0)
    log("reset disparado")
    reset()
    return true
  end
  if cfg("set.reload") == 1 then setcfg("set.reload", 0); reload(); return true end
  return false
end

local function drop()
  if hArr ~= 0 then gchf(hArr); hArr = 0 end
  if hCam ~= 0 then gchf(hCam); hCam = 0 end
  arr = 0
  n = 0
  camE = 0
end

local function refresh()
  if hArr ~= 0 then gchf(hArr); hArr = 0 end
  arr = call(mFOT, objP)
  if arr and arr ~= 0 then hArr = gch(arr) else arr = 0 end
  n = arrlen(arr)
end

local function setup()
  if ticks - lastTry < 20 then return end
  lastTry = ticks
  drop()
  if hP ~= 0 then gchf(hP); hP = 0 end
  if not i2c_ready() then log("sin il2cpp"); return end

  local kP = i2c_class("COW.GamePlay", "Player")
  local kO = i2c_class("UnityEngine", "Object")
  local kT = i2c_class("UnityEngine", "Transform")
  local kC = i2c_class("UnityEngine", "Component")
  local kM = i2c_class("UnityEngine", "Camera")
  log("k="..tostring(kP).." "..tostring(kM))
  if not (kP and kO and kT and kC and kM) then return end

  local fct = sym("il2cpp_class_get_type")
  local fto = sym("il2cpp_type_get_object")
  if not (fct and fto) then log("sin type"); return end

  objP = call(fto, call(fct, kP))
  hP = gch(objP)
  local objC = call(fto, call(fct, kM))

  mFOT = i2c_mptr(kO, "FindObjectsOfType", 1)
  mGT = i2c_mptr(kC, "get_transform", 0)
  mGP = i2c_mptr(kT, "get_position", 0)
  local mGC = i2c_mptr(kC, "GetComponent", 1)
  local mW = i2c_mptr(kM, "get_worldToCameraMatrix", 0)
  local mP = i2c_mptr(kM, "get_projectionMatrix", 0)
  log("m="..tostring(mFOT).." "..tostring(mGT).." "..tostring(mW).." "..tostring(mP))
  if not (mFOT and mGT and mGP and mW and mP) then return end

  refresh()
  log("n="..n)
  if n <= 0 then return end

  local cam = 0
  for i = 0, n - 1 do
    local e = arrat(arr, i)
    if e and e ~= 0 and r64(e + 0x10) ~= 0 then
      local mt = r64(e + 0x3e8)
      if mt and mt ~= 0 then
        local c = call(mGC, mt, objC)
        if c and c ~= 0 then cam = c; break end
      end
    end
  end
  log("cam="..tostring(cam))
  if cam == 0 then return end

  if camset(mW, mP, cam) then
    camE = cam
    hCam = gch(cam)
    camupd()
    matdump()
    setcfg("esp.on", 1)
    log("esp forzado")
    ok = true
  end
end

function tick()
  ticks = ticks + 1
  if boot_cfg() then return end
  if not ok then setup(); return end

  if camE == 0 or r64(camE + 0x10) == 0 then
    log("cam muerta")
    ok = false
    return
  end

  frame = frame + 1
  if frame % 8 == 0 then refresh() end
  if n <= 0 then ok = false; return end

  local dead = 0
  for i = 0, n - 1 do
    local e = arrat(arr, i)
    if e == 0 or r64(e + 0x10) == 0 then dead = dead + 1 end
  end
  if dead * 2 > n then
    log("stale n="..n.." dead="..dead)
    ok = false
    return
  end

  camupd()

  local ctr = call(mGT, camE)
  local cx, cy, cz = 0, 0, 0
  if ctr and ctr ~= 0 then cx, cy, cz = gete(mGP, ctr) end

  clear()

  local w, h = sw(), sh()
  rect(3, 3, w - 6, h - 6, 1, 0, 0, 1)
  line(w / 2 - 25, h / 2, 50, 0, 1, 0, 0, 1)
  line(w / 2, h / 2 - 25, 0, 50, 1, 0, 0, 1)

  local on = cfg("esp.on") == 1
  local box = cfg("esp.box") == 1
  local nm = cfg("esp.name") == 1
  local ln = cfg("draw.line") == 1
  local d = 0
  local nn = n or 0
  local near = 99999

  for i = 0, nn - 1 do
    local e = arrat(arr, i)
    if e ~= 0 and r64(e + 0x10) ~= 0 then
      local tr = call(mGT, e)
      if tr and tr ~= 0 then
        local px, py, pz = gete(mGP, tr)
        local dx, dy, dz = px - cx, py - cy, pz - cz
        if dx * dx + dy * dy + dz * dz > 9 then
          local _, _, _, cw, nx, ny = w2smd(px, py, pz)
          if cw > 0.5 then
            d = d + 1
            if cw < near then near = cw end
            if on then
              local sx = (nx * 0.5 + 0.5) * w
              local sy = (1 - (ny * 0.5 + 0.5)) * h
              if sx > -120 and sx < w + 120 and sy > -60 and sy < h + 500 then
                local bh = 660 / cw
                if bh < 20 then bh = 20 end
                if bh > h * 0.5 then bh = h * 0.5 end
                local bw = bh * 0.45
                local by = sy - bh
                if box then rect(sx - bw / 2, by, bw, bh, 1, 0.15, 0.15, 1) end
                if ln then line(sx, by, w / 2 - sx, -by, 1, 1, 1, 0.85) end
                if nm then text("P"..i, sx - 9, by - 13, 1, 1, 1, 1) end
              end
            end
          end
        end
      end
    end
  end

  text("d="..d.."/"..nn, 12, 16, 1, 1, 0, 1)

  if frame % 20 == 0 then
    if near > 9999 then near = 0 end
    log("f="..frame.." n="..nn.." d="..d.." dead="..dead.." cw="..math.floor(near))
  end
end
