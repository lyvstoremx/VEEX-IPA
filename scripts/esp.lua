-- PROBE46: reset arreglado, posición por Transform.get_position
local hecho = false
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
  if hecho then return end
  if not i2c_ready() then return end
  hecho = true

  local PLC = i2c_class("COW.GamePlay", "Player")
  log("pl=" .. hex(PLC))
  if not PLC then return end
  local to = call(sym("il2cpp_type_get_object"), call(sym("il2cpp_class_get_type"), PLC))
  local OK = i2c_class("UnityEngine", "Object")
  if not OK or not to then log("sin tipo") return end
  local arr = call(i2c_mptr(OK, "FindObjectsOfType", 1), to)
  if not arr or not plaus(arr) then log("arr malo") return end
  local n = arrlen(arr)
  log("n=" .. tostring(n))
  if not n or n <= 0 then return end

  local alvo = nil
  local lim = n
  if lim > 60 then lim = 60 end
  for i = 0, lim - 1 do
    local o = arrat(arr, i)
    if o and o ~= 0 and esPlayer(kl(o)) then alvo = o break end
  end
  log("alvo=" .. hex(alvo))
  if not alvo then return end

  local tr = r64(alvo + 0x700)
  log("tr=" .. hex(tr))
  if tr and tr ~= 0 and plaus(tr) then
    local gm = i2c_mptr(kl(tr), "get_position", 0)
    log("gm=" .. hex(gm))
    if gm and gm ~= 0 then
      local x, y, z = pos3(gm, tr)
      log("POS=" .. tostring(x) .. "," .. tostring(y) .. "," .. tostring(z))
    end
  end

  log("v270=" .. tostring(rf(alvo + 0x270)) .. "," .. tostring(rf(alvo + 0x274)) .. "," .. tostring(rf(alvo + 0x278)))
  log("v7e8=" .. tostring(rf(alvo + 0x7e8)) .. "," .. tostring(rf(alvo + 0x7ec)) .. "," .. tostring(rf(alvo + 0x7f0)))

  local cam = r64(alvo + 0x3e8)
  log("cam=" .. hex(cam))
  if cam and cam ~= 0 and plaus(cam) then
    local cm = i2c_mptr(kl(cam), "get_position", 0)
    if cm and cm ~= 0 then
      local a, b, c = pos3(cm, cam)
      log("CAMPOS=" .. tostring(a) .. "," .. tostring(b) .. "," .. tostring(c))
    end
  end
  log("FIN46")
end
