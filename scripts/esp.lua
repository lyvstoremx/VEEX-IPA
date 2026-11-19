-- PROBE48: ESP con get_transform
local jug, camObj, mW2S, mGT = {}, nil, nil, nil
local prep, cnt, camok = false, 0, false
local SW, SH = 0, 0

local function hex(v) if not v then return "nil" end return string.format("%x", v) end
local function plaus(p) return p and p > 4294967296 and p < 549755813888 and (p % 8) == 0 end
local function esPlayer(k)
  for _, p in ipairs(parents(k)) do
    if string.find(p, "Player") then return true end
  end
  return false
end

function tick()
  if cfg("set.reset") == 1 then setcfg("set.reset", 0) reset() end
  if cfg("set.reload") == 1 then setcfg("set.reload", 0) reload() end
  if not i2c_ready() then return end

  if not prep then
    prep = true
    SW, SH = sw(), sh()
    log("V48 sw=" .. tostring(SW) .. " sh=" .. tostring(SH))
    local fgt = sym("il2cpp_class_get_type")
    local fob = sym("il2cpp_type_get_object")
    local OK = i2c_class("UnityEngine", "Object")
    local Cam = i2c_class("UnityEngine", "Camera")
    local Comp = i2c_class("UnityEngine", "Component")
    log("OK=" .. hex(OK) .. " Cam=" .. hex(Cam) .. " Comp=" .. hex(Comp))
    if not OK or not Cam or not Comp then return end

    mGT = i2c_mptr(Comp, "get_transform", 0)
    log("mGT=" .. hex(mGT))

    local arr = call(i2c_mptr(OK, "FindObjectsOfType", 1), call(fob, call(fgt, Cam)))
    if arr and plaus(arr) then
      local n = arrlen(arr)
      log("cams=" .. tostring(n))
      if n and n > 0 then camObj = arrat(arr, 0) end
    end
    log("camObj=" .. hex(camObj))
    if not camObj then return end
    mW2S = i2c_mptr(kl(camObj), "WorldToScreenPoint", 1)
    log("mW2S=" .. hex(mW2S))
    camok = (mW2S ~= nil and mW2S ~= 0)
    return
  end

  if not camok then return end
  cnt = cnt + 1
  clear()

  if cnt % 6 == 1 then
    jug = {}
    local PLC = i2c_class("COW.GamePlay", "Player")
    local OK = i2c_class("UnityEngine", "Object")
    if PLC and OK then
      local to = call(sym("il2cpp_type_get_object"), call(sym("il2cpp_class_get_type"), PLC))
      local arr = call(i2c_mptr(OK, "FindObjectsOfType", 1), to)
      if arr and plaus(arr) then
        local n = arrlen(arr)
        if n and n > 0 then
          local lim = n
          if lim > 60 then lim = 60 end
          for i = 0, lim - 1 do
            local o = arrat(arr, i)
            if o and o ~= 0 and esPlayer(kl(o)) then jug[#jug + 1] = o end
          end
        end
      end
    end
  end

  local dib = 0
  for _, o in ipairs(jug) do
    local tr = nil
    if mGT and mGT ~= 0 then tr = call(mGT, o) end
    if not tr or tr == 0 then tr = r64(o + 0x700) end
    if tr and tr ~= 0 and plaus(tr) then
      local gm = i2c_mptr(kl(tr), "get_position", 0)
      if gm and gm ~= 0 then
        local px, py, pz = pos3(gm, tr)
        if px and (math.abs(px) + math.abs(py) + math.abs(pz)) > 1 then
          local sx, sy, sz = w2s(mW2S, camObj, px, py, pz)
          if sx and sz and sz > 0 and sx > -200 and sx < SW + 200 then
            local d = math.sqrt(px * px + py * py + pz * pz)
            local h = 30000 / (d + 1)
            if h < 18 then h = 18 end
            if h > 420 then h = 420 end
            local w = h * 0.5
            rect(sx - w / 2, sy - h, w, h, 0, 1, 0.4, 1)
            line(sx, 0, 0, sy - h, 0, 1, 0.4, 0.7)
            text(string.format("%dm", math.floor(d)), sx - 14, sy + 2, 1, 1, 1, 1)
            dib = dib + 1
          end
        end
      end
    end
  end

  if cnt % 20 == 0 then log("V48 jug=" .. #jug .. " dib=" .. dib) end
end
