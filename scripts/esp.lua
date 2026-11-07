log("VEEX v16")

local MG = i2c_cls("MatchGame")
log("MG=" .. tostring(MG))

local gm = MG and i2c_mptr(MG, "GetMatch", 0)
log("gm=" .. tostring(gm))

if gm then
  local inst = call(gm, 0)
  log("match=" .. tostring(inst))
end

function tick()
  clear()
  text("VEEX v16", 70, 105, 1, 1, 1, 1)
end
