-- PROBE31: solo lectura, sin hooks
local step, t0, beat = 0, os.time(), 0
local PLC, L = nil, 0
local cands = {}

local function hex(v)
  if not v then return "nil" end
  return string.format("%x", v)
end

local function plaus(p)
  if not p then return false end
  return p > 4294967296 and p < 549755813888 and (p % 8) == 0
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
    PLC = i2c_class("COW.GamePlay", "Player")
    log("pl=" .. hex(PLC))
    if not PLC then step = 9 return end

    local n = 0
    for _, s in ipairs(fields(PLC)) do log("f " .. s) n = n + 1 end
    log("fn=" .. n)

    local m = 0
    for _, s in ipairs(parents(PLC)) do log("p " .. s) m = m + 1 end
    log("pn=" .. m)

    local k = 0
    for _, s in ipairs(statics(PLC)) do
      log("s " .. s)
      k = k + 1
      local nm = string.match(s, "(%S+)$")
      if nm and (string.find(s, "List") or string.find(s, "HashSet") or string.find(s, "%[%]")) then
        cands[#cands + 1] = nm
      end
    end
    log("sn=" .. k .. " cand=" .. #cands)
    step = 2
    return
  end

  if step == 2 then
    step = 3
    for _, nm in ipairs(cands) do
      local v = sget(PLC, nm)
      log("g " .. nm .. "=" .. hex(v))
      if v and v ~= 0 and L == 0 and plaus(v) then
        L = v
        log("ELEGIDO " .. nm)
      end
    end
    if L == 0 then log("sin candidato") step = 9 return end

    local tam = r32(L + 0x18)
    if not tam or tam < 0 or tam > 400 then
      log("tam raro " .. tostring(tam))
      step = 9
      return
    end
    log("tam=" .. tam)

    local it = r64(L + 0x10)
    log("items=" .. hex(it))
    if not plaus(it) then log("items raro") step = 9 return end

    local lim = tam
    if lim > 5 then lim = 5 end
    for i = 0, lim - 1 do
      local o = r64(it + i * 8)
      local kk = nil
      if o and o ~= 0 then kk = kl(o) end
      log("o[" .. i .. "]=" .. hex(o) .. " k=" .. hex(kk))
    end

    local o0 = r64(it)
    if o0 and o0 ~= 0 then
      local kk = kl(o0)
      if kk and kk ~= 0 then
        local z = 0
        for _, s in ipairs(fields(kk)) do log("F " .. s) z = z + 1 end
        log("Fn=" .. z)
      end
    end

    log("PROBE31 FIN")
    step = 9
    return
  end
end
