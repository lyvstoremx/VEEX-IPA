-- PROBE51: cámara válida y proyección
local prep = false
local camObj, mW2S, mGT, mGC, TR, Cam, PLC = nil, nil, nil, nil, nil, nil, nil

local function hex(v) if not v then return "nil" end return string.format("%x", v) end
local function plaus(p) return p and p > 4294967296 and p < 549755813888 and (p % 8) == 0 end

function tick()
  if cfg("set.reset") == 1 then setcfg("set.reset", 0) reset() end
  if cfg("set.reload") == 1 then setcfg("set.reload", 0) reload() end
  if not i2c_ready() then return end
  if prep then return end
  prep = true

  log("V51")
  local fgt = sym("il2cpp_class_get_type")
  local fob = sym("il2cpp_type_get_object")
  local OK = i2c_class("UnityEngine", "Object")
  Cam = i2c_class("UnityEngine", "Camera")
  TR = i2c_class("UnityEngine", "Transform")
  local Comp = i2c_class("UnityEngine", "Component")
  PLC = i2c_class("COW.GamePlay", "Player")
  log("Cam=" .. hex(Cam) .. " TR=" .. hex(TR) .. " PLC=" .. hex(PLC))
  if not OK or not Cam or not TR or not Comp or not PLC then return end

  mGT = i2c_mptr(Comp, "get_transform", 0)
  mGC = i2c_mptr(Comp, "GetComponent", 1)
  log("mGT=" .. hex(mGT) .. " mGC=" .. hex(mGC))
  if not mGT or mGT == 0 or not mGC or mGC == 0 then return end

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
      for _, p in ipairs(parents(kl(o))) do
        if string.find(p, "Player") then alvo = o break end
      end
    end
    if alvo then break end
  end
  log("alvo=" .. hex(alvo))
  if not alvo then return end

  local trc = r64(alvo + 0x3e8)
  if not trc or trc == 0 or not plaus(trc) then log("sin trc") return end
  if kl(trc) ~= TR then log("trc no es Transform") return end

  local cto = call(fob, call(fgt, Cam))
  camObj = call(mGC, trc, cto)
  log("camObj=" .. hex(camObj))
  if not camObj or camObj == 0 or not plaus(camObj) then return end
  if kl(camObj) ~= Cam then log("cam no es Camera") return end

  mW2S = i2c_mptr(Cam, "WorldToScreenPoint", 1)
  log("mW2S=" .. hex(mW2S))
  if not mW2S or mW2S == 0 then return end

  local tr = call(mGT, alvo)
  log("tr=" .. hex(tr))
  if not tr or tr == 0 or not plaus(tr) then return end

  local gm = i2c_mptr(TR, "get_position", 0)
  log("gm=" .. hex(gm))
  if not gm or gm == 0 then return end

  local x, y, z = pos3(gm, tr)
  log("pos=" .. tostring(x) .. "," .. tostring(y) .. "," .. tostring(z))
  if not x then return end

  local sx, sy, sz = w2s(mW2S, camObj, x, y, z)
  log("S=" .. tostring(sx) .. "," .. tostring(sy) .. " z=" .. tostring(sz))
  if not sx or not sz then return end

  clear()
  if sz > 0 then
    rect(sx - 20, sy - 80, 40, 80, 0, 1, 0.4, 1)
    text("X", sx - 4, sy + 2, 1, 1, 1, 1)
    log("DIBUJADO")
  else
    log("z<=0")
  end
  log("FIN51")
end
