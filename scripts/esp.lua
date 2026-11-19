-- PROBE36: caza del contenedor, filtrada, con topes. Solo lectura.
local step, t0, beat = 0, os.time(), 0
local PLC, cands, seen, vis = nil, {}, {}, {}
local mejor, mejorP = nil, 0
local lineas, sg = 0, 0

local function L(s)
  if lineas >= 300 then return end
  lineas = lineas + 1
  log(s)
end

local function hex(v) if not v then return "nil" end return string.format("%x", v) end
local function plaus(p) if not p then return false end return p > 4294967296 and p < 549755813888 and (p % 8) == 0 end
local function col(s) return string.find(s, "List") or string.find(s, "HashSet") or string.find(s, "Dictionary") or string.find(s, "%[%]") end
local function esP(s) return string.find(s, "Player") or string.find(s, "Avatar") end
local function objT(s) return string.find(s, "Manager") or string.find(s, "Facade") or string.find(s, "Scene") or string.find(s, "Battle") end

local function esPlayer(k)
  if not k or k == 0 then return false end
  if k == PLC then return true end
  for _, p in ipairs(parents(k)) do
    if string.find(p, "Player") then return true end
  end
  return false
end

local function addc(k, n, tag)
  if #cands >= 60 then return end
  cands[#cands + 1] = { k = k, n = n, t = tag }
end

local function mirar(k, prof)
  if not k or k == 0 or prof > 1 then return end
  if vis[k] then return end
  vis[k] = true

  for _, b in ipairs(fields(k)) do
    local off, ty, nm = string.match(b, "^0x(%x+) (%S+) (%S+)$")
    if off and ty and nm and col(ty) and esP(ty) then
      L("F " .. b)
      addc(k, nm, "inst")
    end
  end

  for _, s in ipairs(statics(k)) do
    if sg >= 400 then return end
    local nm = string.match(s, "(%S+)$")
    if nm and col(s) and esP(s) then
      L("cand " .. s)
      addc(k, nm, "st")
    elseif nm and not col(s) and objT(s) then
      sg = sg + 1
      local o = sget(k, nm)
      if o and o ~= 0 and plaus(o) then
        local kk = kl(o)
        if kk and kk ~= 0 then
          L("hop " .. nm .. "=" .. hex(o) .. " k=" .. hex(kk))
          mirar(kk, prof + 1)
        end
      end
    end
  end
end

function tick()
  log("V36")
  if cfg("set.reset") == 1 then setcfg("set.reset", 0) reset() end
  if cfg("set.reload") == 1 then setcfg("set.reload", 0) reload() end
  if not i2c_ready() then return end

  local ahora = os.time()
  if ahora - beat >= 5 then
    beat = ahora
    log("VIVO36 t=" .. (ahora - t0) .. " s=" .. step .. " c=" .. #cands .. " l=" .. lineas .. " sg=" .. sg)
  end

  if step == 0 then
    step = 1
    PLC = i2c_class("COW.GamePlay", "Player")
    log("pl=" .. hex(PLC))
    if not PLC then step = 9 return end

    local qs = { "Player", "Manager", "Facade", "Scene", "Battle" }
    for _, q in ipairs(qs) do
      local t = dump(q, 200)
      local n = 0
      for _, c in ipairs(t) do
        if c.p and c.p ~= 0 and not seen[c.p] then
          seen[c.p] = true
          n = n + 1
          mirar(c.p, 0)
        end
      end
      L("q_" .. q .. "=" .. n)
    end
    L("cand_total=" .. #cands)
    step = 2
    return
  end

  if step == 2 then
    step = 3
    for _, c in ipairs(cands) do
      local v = sget(c.k, c.n)
      local p = 0
      local tam, it
      if v and v ~= 0 and plaus(v) then
        tam = r32(v + 0x18)
        it = r64(v + 0x10)
        local o = nil
        if tam and tam > 0 and tam < 2000 and plaus(it) then
          o = r64(it)
          p = 2
        else
          local cta = r32(v + 0x20)
          local ent = r64(v + 0x18)
          if cta and cta > 0 and cta < 2000 and plaus(ent) then
            o = r64(ent + 0x10)
            p = 1
          end
        end
        if o and o ~= 0 and esPlayer(kl(o)) then p = p + 5 end
        L("g " .. c.t .. " " .. c.n .. "=" .. hex(v) .. " tam=" .. tostring(tam) .. " p=" .. p)
        if p > mejorP then
          mejorP = p
          mejor = { v = v, p = p, t = c.t, n = c.n }
        end
      else
        L("g " .. c.t .. " " .. c.n .. "=" .. hex(v) .. " p=0")
      end
    end

    if not mejor or mejorP < 2 then log("nada solido") step = 9 return end
    log("MEJOR " .. mejor.t .. " " .. mejor.n .. " p=" .. mejorP .. " obj=" .. hex(mejor.v))
    local tam = r32(mejor.v + 0x18)
    local it = r64(mejor.v + 0x10)
    log("tam=" .. tostring(tam) .. " items=" .. hex(it))
    if tam and tam > 0 and plaus(it) then
      local lim = tam
      if lim > 6 then lim = 6 end
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
          for _, s in ipairs(fields(kk)) do
            if z < 40 then log("FF " .. s) end
            z = z + 1
          end
          log("FFn=" .. z)
        end
      end
    end
    log("PROBE36 FIN")
    step = 9
    return
  end
end
