-- PROBE40: nivel 0 estáticos, nivel 1 campos. Solo lectura.
local step, t0, beat = 0, os.time(), 0
local PLC, cands, seen, vis = nil, {}, {}, {}
local mejor, mejorP = nil, 0
local lineas = 0

local function L(s)
  if lineas >= 400 then return end
  lineas = lineas + 1
  log(s)
end

local function hex(v) if not v then return "nil" end return string.format("%x", v) end
local function rango(p) return p and p > 4294967296 and p < 549755813888 end
local function plaus(p) return rango(p) and (p % 8) == 0 end
local function col(s) return string.find(s, "List") or string.find(s, "HashSet") or string.find(s, "Dictionary") or string.find(s, "%[%]") end
local function esP(s)
  return string.find(s, "GamePlay.Player") or string.find(s, "ReplicationEntity") or string.find(s, "AttackableEntity")
end
local function objT(s)
  return string.find(s, "Manager") or string.find(s, "Facade") or string.find(s, "Scene")
      or string.find(s, "Battle") or string.find(s, "Entity") or string.find(s, "Replication")
      or string.find(s, "Match")
end

local function esClase(k)
  if not rango(k) then return false end
  local np = r64(k + 0x10)
  if not rango(np) then return false end
  local c = r32(np)
  if not c then return false end
  local b0 = c % 256
  local b1 = math.floor(c / 256) % 256
  if b0 < 65 or b0 > 122 then return false end
  if b1 == 95 or b1 == 60 or b1 == 48 then return true end
  return (b1 >= 65 and b1 <= 90) or (b1 >= 97 and b1 <= 122)
end

local function esPlayer(k)
  if not esClase(k) then return false end
  if k == PLC then return true end
  for _, p in ipairs(parents(k)) do
    if string.find(p, "Player") then return true end
  end
  return false
end

local function addS(k, n)
  if #cands >= 80 then return end
  cands[#cands + 1] = { st = 1, k = k, n = n }
end
local function addI(o, off)
  if #cands >= 80 or not off or off > 0x1000 then return end
  cands[#cands + 1] = { st = 0, o = o, f = off }
end

local function campos(k, inst, tope)
  local n = 0
  for _, b in ipairs(fields(k)) do
    local off, ty, nm = string.match(b, "^0x(%x+) (%S+) (%S+)$")
    if off and ty and nm then
      if col(ty) and esP(ty) then
        L("I " .. nm .. " " .. b)
        addI(inst, tonumber(off, 16))
        n = n + 1
      elseif n < tope and (col(ty) or objT(ty) or string.find(ty, "Transform")) then
        L("f " .. b)
        n = n + 1
      end
    end
  end
end

local function mirar(k, inst, prof)
  if not k or k == 0 or prof > 1 then return end
  local clave = k + (inst and 1 or 0) * 0x100000000
  if vis[clave] then return end
  vis[clave] = true

  if prof == 0 then
    for _, s in ipairs(statics(k)) do
      local nm = string.match(s, "(%S+)$")
      if nm and col(s) and esP(s) then
        L("S " .. s)
        addS(k, nm)
      elseif nm and not col(s) and objT(s) then
        local o = sget(k, nm)
        if o and o ~= 0 and plaus(o) then
          local kk = kl(o)
          if kk and kk ~= 0 and esClase(kk) then
            L("hop " .. nm .. "=" .. hex(o) .. " k=" .. hex(kk))
            mirar(kk, o, 1)
          else
            L("skip " .. nm .. "=" .. hex(o) .. " k=" .. hex(kk))
          end
        end
      end
    end
  else
    local pp = parents(k)
    local s = ""
    for _, p in ipairs(pp) do s = s .. " " .. p end
    L("cls " .. hex(k) .. " padre:" .. s)
    campos(k, inst, 60)
  end
end

function tick()
  if cfg("set.reset") == 1 then setcfg("set.reset", 0) reset() end
  if cfg("set.reload") == 1 then setcfg("set.reload", 0) reload() end
  if not i2c_ready() then return end

  local ahora = os.time()
  if ahora - beat >= 5 then
    beat = ahora
    log("VIVO40 t=" .. (ahora - t0) .. " s=" .. step .. " c=" .. #cands .. " l=" .. lineas)
  end

  if step == 0 then
    step = 1
    PLC = i2c_class("COW.GamePlay", "Player")
    log("pl=" .. hex(PLC))
    if not PLC then step = 9 return end

    local qs = { "Player", "Entity", "Replication", "Manager", "BattleBoard", "Spawn", "Facade", "Match" }
    for _, q in ipairs(qs) do
      local t = dump(q, 200)
      local n = 0
      for _, c in ipairs(t) do
        if c.p and c.p ~= 0 and not seen[c.p] then
          seen[c.p] = true
          n = n + 1
          mirar(c.p, nil, 0)
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
      local v = nil
      if c.st == 1 then
        v = sget(c.k, c.n)
      elseif plaus(c.o) then
        v = r64(c.o + c.f)
      end
      local et = c.st == 1 and ("st " .. c.n) or ("in " .. string.format("%x", c.f))
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
        L("g " .. et .. "=" .. hex(v) .. " tam=" .. tostring(tam) .. " p=" .. p)
        if p > mejorP then
          mejorP = p
          mejor = { v = v, p = p, et = et }
        end
      else
        L("g " .. et .. "=" .. hex(v) .. " p=0")
      end
    end

    if not mejor or mejorP < 2 then log("nada solido") step = 9 return end
    log("MEJOR " .. mejor.et .. " p=" .. mejorP .. " obj=" .. hex(mejor.v))
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
    end
    log("PROBE40 FIN")
    step = 9
    return
  end
end
