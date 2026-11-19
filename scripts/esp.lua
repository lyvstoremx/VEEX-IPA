-- PROBE33: caza del contenedor. Solo lectura.
local step, t0, beat = 0, os.time(), 0
local L = 0
local cands = {}
local seen = {}

local function hex(v)
  if not v then return "nil" end
  return string.format("%x", v)
end

local function plaus(p)
  if not p then return false end
  return p > 4294967296 and p < 549755813888 and (p % 8) == 0
end

local function islist(s)
  return string.find(s, "List") or string.find(s, "HashSet")
    or string.find(s, "Dictionary") or string.find(s, "%[%]")
end

local function scan(kl, tag)
  local n = 0
  for _, s in ipairs(statics(kl)) do
    local nm = string.match(s, "(%S+)$")
    if nm and islist(s) then
      cands[#cands + 1] = { k = kl, n = nm, t = tag, ty = s }
      log("cand " .. tag .. " " .. s)
      n = n + 1
    end
  end
  return n
end

function tick()
  if cfg("set.reset") == 1 then setcfg("set.reset", 0) reset() end
  if cfg("set.reload") == 1 then setcfg("set.reload", 0) reload() end
  if not i2c_ready() then return end

  local ahora = os.time()
  if ahora - beat >= 5 then
    beat = ahora
    log("VIVO t=" .. (ahora - t0) .. " s=" .. step .. " L=" .. hex(L))
  end

  if step == 0 then
    step = 1
    local PLC = i2c_class("COW.GamePlay", "Player")
    log("pl=" .. hex(PLC))
    if not PLC then step = 9 return end

    local qs = { "Manager", "Facade", "Match", "Room", "Scene", "Entity",
                 "Replication", "Battle", "World", "Game", "Local", "Data" }
    local cls = {}
    for _, q in ipairs(qs) do
      local t = dump(q, 25)
      local k = 0
      for _, c in ipairs(t) do
        local ns = c.s
        if not ns or ns == "" then ns = "-" end
        log("d " .. ns .. "::" .. c.n .. " " .. hex(c.p))
        k = k + 1
        if c.p and c.p ~= 0 and not seen[c.p] and #cls < 150 then
          seen[c.p] = true
          cls[#cls + 1] = { k = c.p, n = c.n }
        end
      end
      log("dq_" .. q .. "=" .. k)
    end
    log("cls=" .. #cls)

    for _, c in ipairs(cls) do scan(c.k, c.n) end
    log("cand_total=" .. #cands)
    step = 2
    return
  end

  if step == 2 then
    step = 3
    for _, c in ipairs(cands) do
      local v = sget(c.k, c.n)
      log("g " .. c.t .. " " .. c.n .. "=" .. hex(v))
      if v and v ~= 0 and L == 0 and plaus(v) then
        L = v
        log("ELEGIDO " .. c.t .. " " .. c.n)
      end
    end
    if L == 0 then log("sin candidato") step = 9 return end

    local tam = r32(L + 0x18)
    if not tam or tam < 0 or tam > 2000 then
      log("tam raro " .. tostring(tam))
      step = 9
      return
    end
    log("tam=" .. tam)

    local it = r64(L + 0x10)
    log("items=" .. hex(it))
    if not plaus(it) then log("items raro") step = 9 return end

    local lim = tam
    if lim > 6 then lim = 6 end
    for i = 0, lim - 1 do
      local o = r64(it + i * 8)
      local kk = nil
      if o and o ~= 0 then kk = kl(o) end
      log("o[" .. i .. "]=" .. hex(o) .. " k=" .. hex(kk))
    end

    log("PROBE33 FIN")
    step = 9
    return
  end
end
