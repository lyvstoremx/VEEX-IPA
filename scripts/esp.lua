-- PROBE34: caza del contenedor, dos saltos. Solo lectura.
local step, t0, beat = 0, os.time(), 0
local PLC = nil
local cands = {}
local seen = {}
local mejor, mejorP = nil, 0

local function hex(v) if not v then return "nil" end return string.format("%x", v) end
local function plaus(p) if not p then return false end return p > 4294967296 and p < 549755813888 and (p % 8) == 0 end
local function col(s) return string.find(s, "List") or string.find(s, "HashSet") or string.find(s, "Dictionary") or string.find(s, "%[%]") end
local function esP(s) return string.find(s, "Player") or string.find(s, "Avatar") end

local function esPlayer(k)
  if not k or k == 0 then return false end
  if k == PLC then return true end
  for _, p in ipairs(parents(k)) do
    if string.find(p, "Player") then return true end
  end
  return false
end

local function addc(k, n, off, tag)
  if #cands >= 200 then return end
  cands[#cands + 1] = { k = k, n = n, o = off, t = tag }
end

local function mirar(k, tag)
  local f = fields(k)
  local hay = false
  for _, b in ipairs(f) do
    local off, ty, nm = string.match(b, "^0x(%x+) (%S+) (%S+)$")
    if off and ty and nm and col(ty) and esP(ty) then
      log("F " .. tag .. " " .. b)
      hay = true
    end
  end
  for _, s in ipairs(statics(k)) do
    local nm = string.match(s, "(%S+)$")
    if nm and col(s) and esP(s) then
      log("cand " .. tag .. " " .. s)
      addc(k, nm, nil, tag)
    elseif nm and not col(s) and (string.find(s, "Manager") or string.find(s, "Facade")
        or string.find(s, "Scene") or string.find(s, "Battle")) then
      local o = sget(k, nm)
      if o and o ~= 0 and plaus(o) then
        local kk = kl(o)
        log("hop " .. tag .. " " .. nm .. "=" .. hex(o) .. " k=" .. hex(kk))
        if kk and kk ~= 0 then mirar(kk, tag .. ">" .. nm) end
      end
    end
  end
  return hay
end

function tick()
  log("V34")
  if cfg("set.reset") == 1 then setcfg("set.reset", 0) reset() end
  if cfg("set.reload") == 1 then setcfg("set.reload", 0) reload() end
  if not i2c_ready() then return end

  local ahora = os.time()
  if ahora - beat >= 5 then
    beat = ahora
    log("VIVO t=" .. (ahora - t0) .. " s=" .. step .. " c=" .. #cands)
  end

  if step == 0 then
    step = 1
    PLC = i2c_class("COW.GamePlay", "Player")
    log("pl=" .. hex(PLC))
    if not PLC then step = 9 return end

    local qs = { "PlayerManager", "Player", "PlayerSpawn", "AllPlayer",
                 "EntityManager", "GameScene", "BattleManager", "MatchManager",
                 "RoomManager", "GamePlayManager", "SceneManager" }
    local cls = {}
    for _, q in ipairs(qs) do
      local t = dump(q, 30)
      local k = 0
      for _, c in ipairs(t) do
        local ns = c.s
        if not ns or ns == "" then ns = "-" end
        log("d " .. ns .. "::" .. c.n .. " " .. hex(c.p))
        k = k + 1
        if c.p and c.p ~= 0 and not seen[c.p] and #cls < 120 then
          seen[c.p] = true
          cls[#cls + 1] = { k = c.p, n = c.n }
        end
      end
      log("dq_" .. q .. "=" .. k)
    end
    log("cls=" .. #cls)

    for _, c in ipairs(cls) do
      if string.find(c.n, "Player") or string.find(c.n, "Manager")
         or string.find(c.n, "Scene") or string.find(c.n, "Battle") then
        mirar(c.k, c.n)
      end
    end
    log("cand_total=" .. #cands)
    step = 2
    return
  end

  if step == 2 then
    step = 3
    for _, c in ipairs(cands) do
      local v = sget(c.k, c.n)
      local p = 0
      if v and v ~= 0 and plaus(v) then
        local tam = r32(v + 0x18)
        local it = r64(v + 0x10)
        local cta = r32(v + 0x20)
        local ent = r64(v + 0x18)
        local o = nil
        if tam and tam > 0 and tam < 2000 and plaus(it) then
          o = r64(it)
          p = 2
        elseif cta and cta > 0 and cta < 2000 and plaus(ent) then
          o = r64(ent + 0x10)
          p = 1
        end
        if o and o ~= 0 and esPlayer(kl(o)) then p = p + 5 end
        log("g " .. c.t .. " " .. c.n .. "=" .. hex(v) .. " tam=" .. tostring(tam) .. " p=" .. p)
        if p > mejorP then
          mejorP = p
          mejor = { v = v, o = o, p = p, t = c.t, n = c.n, l = (tam and tam > 0) }
        end
      else
        log("g " .. c.t .. " " .. c.n .. "=" .. hex(v) .. " p=0")
      end
    end

    if not mejor or mejorP < 2 then log("nada solido") step = 9 return end
    log("MEJOR " .. mejor.t .. " " .. mejor.n .. " p=" .. mejorP .. " obj=" .. hex(mejor.v))
    if mejor.l then
      local tam = r32(mejor.v + 0x18)
      local it = r64(mejor.v + 0x10)
      log("tam=" .. tostring(tam) .. " items=" .. hex(it))
      local lim = tam
      if lim > 6 then lim = 6 end
      for i = 0, lim - 1 do
        local o = r64(it + i * 8)
        local kk = nil
        if o and o ~= 0 then kk = kl(o) end
        log("o[" .. i .. "]=" .. hex(o) .. " k=" .. hex(kk))
      end
      if lim > 0 then
        local o0 = r64(it)
        if o0 and o0 ~= 0 then
          local kk = kl(o0)
          if kk and kk ~= 0 then
            local z = 0
            for _, s in ipairs(fields(kk)) do log("FF " .. s) z = z + 1 end
            log("FFn=" .. z)
          end
        end
      end
    end
    log("PROBE34 FIN")
    step = 9
    return
  end
end
