-- esp.lua V54
log("V54 sw="..sw().." sh="..sh())

local ok = false
local n = 0
local arr = 0
local frame = 0
local mFOT, mGC, mGP, objT
local said = false

local function boot_cfg()
  if cfg("set.reset") == 1 then setcfg("set.reset", 0); reset(); return true end
  if cfg("set.reload") == 1 then setcfg("set.reload", 0); reload(); return true end
  return false
end

local function setup()
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

  local objP = call(fto, call(fct, kP))
  objT = call(fto, call(fct, kT))
  local objC = call(fto, call(fct, kM))

  mFOT = i2c_mptr(kO, "FindObjectsOfType", 1)
  mGC = i2c_mptr(kC, "GetComponent", 1)
  mGP = i2c_mptr(kT, "get_position", 0)
  local mW = i2c_mptr(kM, "get_worldToCameraMatrix", 0)
  local mP = i2c_mptr(kM, "get_projectionMatrix", 0)
  log("m="..tostring(mFOT).." "..tostring(mGC).." "..tostring(mW).." "..tostring(mP))
  if not (mFOT and mGC and mGP and mW and mP) then return end

  arr = call(mFOT, objP)
  n = arrlen(arr)
  log("n="..n)
  if n <= 0 then return end

  local cam = 0
  for i = 0, n - 1 do
    local e = arrat(arr, i)
    if e and e ~= 0 then
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
    camupd()
    matdump()
    setcfg("esp.on", 1)
    log("esp forzado")
    ok = true
  end
end

function tick()
  if boot_cfg() then return end
  if not ok then setup(); return end

  frame = frame + 1
  if frame % 5 == 1 then arr = call(mFOT, objP); n = arrlen(arr) end
  camupd()
  clear()
  if not n or n <= 0 then return end

  local w, h = sw(), sh()
  local on = cfg("esp.on") == 1
  local box = cfg("esp.box") == 1
  local nm = cfg("esp.name") == 1
  local ln = cfg("draw.line") == 1
  local d = 0
  local sx0, sy0 = 0, 0

  for i = 0, n - 1 do
    local e = arrat(arr, i)
    if e and e ~= 0 then
      local tr = call(mGC, e, objT)
      if tr and tr ~= 0 then
        local px, py, pz = gete(mGP, tr)
        if px > -9000 and px < 9000 then
          local fx, fy, fv = w2sm(px, py, pz)
          local hx, hy, hv = w2sm(px, py + 180, pz)
          if fv and hv then
            d = d + 1
            if d == 1 then sx0, sy0 = fx, fy end
            if on then
              local bh = math.abs(fy - hy)
              if bh < 12 then bh = 12 end
              if bh > 300 then bh = 300 end
              local bw = bh * 0.55
              local cx = (fx + hx) * 0.5
              if box then rect(cx - bw / 2, hy, bw, bh, 0.1, 0.95, 0.35, 1) end
              if ln then line(cx, hy + bh, w / 2, h - 6, 0.95, 0.9, 0.15, 1) end
              if nm then text("P"..i, cx - 9, hy - 13, 1, 1, 1, 1) end
            end
          end
        end
      end
    end
  end

  if frame % 20 == 0 then log("d="..d.."/"..n.." on="..tostring(on)) end
  if d > 0 and not said then said = true; log("first "..math.floor(sx0)..","..math.floor(sy0)) end
end
