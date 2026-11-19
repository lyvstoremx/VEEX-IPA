-- PROBE47: busca el offset de posición comparando con la cámara
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
  if not PLC then log("sin clase") return end
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

  local cam = r64(alvo + 0x3e8)
  if not cam or cam == 0 or not plaus(cam) then log("sin cam") return end
  local cm = i2c_mptr(kl(cam), "get_position", 0)
  if not cm or cm == 0 then log("sin getpos") return end
  local cx, cy, cz = pos3(cm, cam)
  log("cam=" .. tostring(cx) .. "," .. tostring(cy) .. "," .. tostring(cz))

  log("v320=" .. tostring(rf(alvo + 0x320)) .. "," .. tostring(rf(alvo + 0x324)) .. "," .. tostring(rf(alvo + 0x328)))
  log("v344=" .. tostring(rf(alvo + 0x344)) .. "," .. tostring(rf(alvo + 0x348)) .. "," .. tostring(rf(alvo + 0x34c)))
  log("v52c=" .. tostring(rf(alvo + 0x52c)) .. "," .. tostring(rf(alvo + 0x530)) .. "," .. tostring(rf(alvo + 0x534)))

  local k = 0
  for off = 0x10, 0x2600, 4 do
    local x = rf(alvo + off)
    local y = rf(alvo + off + 4)
    local z = rf(alvo + off + 8)
    if math.abs(x - cx) < 5000 and math.abs(y - cy) < 5000 and math.abs(z - cz) < 5000
       and (math.abs(x) + math.abs(y) + math.abs(z)) > 1 then
      k = k + 1
      if k <= 12 then
        log("hit 0x" .. string.format("%x", off) .. "=" .. tostring(x) .. "," .. tostring(y) .. "," .. tostring(z))
      end
    end
  end
  log("hits=" .. k)
  log("FIN47")
end
