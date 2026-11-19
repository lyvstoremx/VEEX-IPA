-- esp.lua V65
log("V65 sw="..sw().." sh="..sh())

local ok = false
local n = 0
local arr = 0
local hArr = 0
local frame = 0
local ticks = 0
local mFOT, mGP, mGT, objP

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

local function refresh()
  if hArr ~= 0 then gchf(hArr); hArr = 0 end
  arr = call(mFOT, objP)
  if arr and arr ~= 0 then hArr = gch(arr) end
  n = arrlen(arr)
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

  objP = gch(call(fto, call(fct, kP)))
  local objC = call(fto, call(fct, kM))

  mFOT = i2c_mptr(kO, "FindObjectsOfType", 1)
  mGT = i2c_mptr(kC, "get_transform", 0)
  mGP = i2c_mptr(kT, "get_position", 0)
  local mGC = i2c_mptr(kC, "GetComponent", 1)
  local mW = i2c_mptr(kM, "get_worldToCameraMatrix", 0)
  local mP = i2c_mptr(kM, "get_projectionMatrix", 0)
  if not mP then mP = i2c_mptr(kM, "get_projectionMatrix", 0) end
  log("m="..tostring(mFOT).." "..tostring(mGT).." "..tostring(mW).." "..tostring(mP))
  if not (mFOT and mGT and mGP and mW and mP) then return end

  refresh()
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
  ticks = ticks + 1
  if boot_cfg() then return end
  if not ok then setup(); return end

  frame = frame + 1
  refresh()
  camupd()
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
  local top = h * 0.35

  for i = 0, nn - 1 do
    local e = arrat(arr, i)
    if e and e ~= 0 then
      local tr = call(mGT, e)
      if tr and tr ~= 0 then
        local px, py, pz = gete(mGP, tr)
        if px > -9000 and px < 9000 then
          local fx, fy, fv = w2sm(px, py, pz)
          if fv then
            d = d + 1
            if on then
              local hx, hy = w2smu(px, py + 180, pz)
              local bh = math.abs(fy - hy)
              if bh < 26 then bh = 26 end
              if bh > top then bh = top end
              local by = fy - bh
              local bw = bh * 0.5
              if box then rect(fx - bw / 2, by, bw, bh, 0.1, 0.95, 0.35, 1) end
              if ln then line(fx, fy, w / 2, h - 6, 0.95, 0.9, 0.15, 1) end
              if nm then text("P"..i, fx - 9, by - 13, 1, 1, 1, 1) end
            end
          end
        end
      end
    end
  end

  text("d="..d.."/"..nn, 12, 16, 1, 1, 0, 1)

  if frame % 20 == 0 then log("f="..frame.." n="..nn.." d="..d) end
end
