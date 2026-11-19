-- PROBE49: un jugador, pasos marcados
local prep, camok, camObj, mW2S, mGT, TR = false, false, nil, nil, nil, nil
local SW, SH = 0, 0
local PLC = nil

local function hex(v) if not v then return "nil" end return string.format("%x", v) end
local function plaus(p) return p and p > 4294967296 and p < 549755813888 and (p % 8) == 0 end

function tick()
  if cfg("set.reset") == 1 then setcfg("set.reset", 0) reset() end
  if cfg("set.reload") == 1 then setcfg("set.reload", 0) reload() end
  if not i2c_ready() then return end
  if prep then return end
  prep = true

  SW, SH = sw(), sh()
  log("V49")
  local fgt = sym("il2cpp_class_get_type")
  local fob = sym("il2cpp_type_get_object")
  local OK = i2c_class("UnityEngine", "Object")
  local Cam = i2c_class("UnityEngine", "Camera")
  local Comp = i2c_class("UnityEngine", "Component")
  TR = i2c_class("UnityEngine", "Transform")
  PLC = i2c_class("COW.GamePlay", "Player")
  log("TR=" .. hex(TR) .. " PLC=" .. hex(PLC))
  if not OK or not Cam or not Comp or not TR or not PLC then return end

  mGT = i2c_mptr(Comp, "get_transform", 0)
  log("mGT=" .. hex(mGT))
  if not mGT or mGT == 0 then return end

  local arr = call(i2c_mptr(OK, "FindObjectsOfType", 1), call(fob, call(fgt, Cam)))
  if arr and plaus(arr) then
    local n = arrlen(arr)
    if n and n > 0 then camObj = arrat(arr, 0) end
  end
  log("camObj=" .. hex(camObj))
  if not camObj then return end
  mW2S = i2c_mptr(kl(camObj), "WorldToScreenPoint", 1)
  log("mW2S=" .. hex(mW2S))
  if not mW2S or mW2S == 0 then return end
  camok = true

  local to = call(fob, call(fgt, PLC))
  local pa = call(i2c_mptr(OK, "FindObjectsOfType", 1), to)
  if not pa or not plaus(pa) then log("sin array") return end
  local n = arrlen(pa)
  log("n=" .. tostring(n))
  if not n or n <= 0 then return end

  local alvo = nil
  for i = 0, math.min(n, 60) - 1 do
    local o = arrat(pa, i)
    if o and o ~= 0 then
      local k = kl(o)
      for _, p in ipairs(parents(k)) do
        if string.find(p, "Player") then alvo = o break end
      end
    end
    if alvo then break end
  end
  log("A alvo=" .. hex(alvo))
  if not alvo then return end

  local tr = call(mGT, alvo)
  log("B tr=" .. hex(tr))
  if not tr or tr == 0 or not plaus(tr) then
    tr = r64(alvo + 0x700)
    log("B2 campo=" .. hex(tr))
  end
  if not tr or tr == 0 or not plaus(tr) then return end
  log("C kl(tr)=" .. hex(kl(tr)) .. " esTR=" .. tostring(kl(tr) == TR))

  local gm = i2c_mptr(kl(tr), "get_position", 0)
  log("D gm=" .. hex(gm))
  if not gm or gm == 0 then return end

  local px, py, pz = pos3(gm, tr)
  log("E pos=" .. tostring(px) .. "," .. tostring(py) .. "," .. tostring(pz))
  if not px then return end

  local sx, sy, sz = w2s(mW2S, camObj, px, py, pz)
  log("F sxy=" .. tostring(sx) .. "," .. tostring(sy) .. " sz=" .. tostring(sz))
  if not sx or not sz then return end

  clear()
  if sz > 0 then
    rect(sx - 20, sy - 80, 40, 80, 0, 1, 0.4, 1)
    line(sx, 0, 0, sy - 80, 0, 1, 0.4, 0.7)
    text("X", sx - 4, sy + 2, 1, 1, 1, 1)
    log("G dibujado")
  else
    log("G sz<=0")
  end
  log("FIN49")
end
