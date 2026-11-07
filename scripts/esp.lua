log("VEEX v8")

local MG = i2c_cls("MatchGame")
local G = i2c_cls("GameFacade")

local gm = MG and i2c_mptr(MG, "GetMatch", 0)
log("gm=" .. tostring(gm))
local inst = nil
if gm then inst = call(gm, 0) end
log("match=" .. tostring(inst))

if inst and inst ~= 0 then
  local gre = i2c_mptr(MG, "GetRepEntity", 1)
  log("gre=" .. tostring(gre))
  if gre then
    local ib = buf(4)
    local found = 0
    for id = 0, 60 do
      w32(ib, id)
      local e = callv(gre, inst, ib)
      if e and e ~= 0 then
        local lo = r32(e)
        local hi = r32(e + 4)
        local k = hi * 4294967296 + lo
        log("E" .. id .. " " .. i2c_cname(k))
        found = found + 1
        if found >= 8 then break end
      end
    end
    log("found=" .. found)
  end
end

local clp = G and i2c_mptr(G, "CurrentLocalPlayer", 0)
log("clp=" .. tostring(clp))
if clp then
  local lp = call(clp, 0)
  log("lp=" .. tostring(lp))
end

function tick()
  clear()
  text("VEEX v8", 70, 105, 1, 1, 1, 1)
end
