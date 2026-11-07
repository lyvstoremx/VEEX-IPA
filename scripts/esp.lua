log("VEEX v15")

local MG = i2c_cls("MatchGame")
local gm = MG and i2c_mptr(MG, "GetMatch", 0)
log("gm=" .. tostring(gm))

if gm then
  local inst = call(gm, 0)
  log("match=" .. tostring(inst))
  if inst and inst ~= 0 then
    local gre = i2c_mptr(MG, "GetRepEntity", 1)
    log("gre=" .. tostring(gre))
    if gre then
      local ib = buf(4)
      local f = 0
      for id = 0, 60 do
        w32(ib, id)
        local e = callv(gre, inst, ib)
        if e and e ~= 0 then
          local lo = r32(e)
          local hi = r32(e + 4)
          log("E" .. id .. " " .. i2c_cname(hi * 4294967296 + lo))
          f = f + 1
          if f >= 6 then break end
        end
      end
      log("found=" .. f)
    end
  end
end

function tick()
  clear()
  text("VEEX v15", 70, 105, 1, 1, 1, 1)
end
