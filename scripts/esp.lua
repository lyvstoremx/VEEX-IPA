log("VEEX v11")

local giz = i2c_ptr("TransformGizmo", "get_MyCamera", 0)
local cam = nil
if giz then cam = call(giz, 0) end
log("cam=" .. tostring(cam))

if cam and cam ~= 0 then
  local pw = i2c_ptr("Camera", "get_pixelWidth", 0)
  local ph = i2c_ptr("Camera", "get_pixelHeight", 0)
  if pw then log("w=" .. tostring(call(pw, cam))) end
  if ph then log("h=" .. tostring(call(ph, cam))) end
end

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
      local found = 0
      for id = 0, 60 do
        w32(ib, id)
        local e = callv(gre, inst, ib)
        if e and e ~= 0 then
          local lo = r32(e)
          local hi = r32(e + 4)
          log("E" .. id .. " " .. i2c_cname(hi * 4294967296 + lo))
          found = found + 1
          if found >= 6 then break end
        end
      end
      log("found=" .. found)
    end
  end
end

function tick()
  clear()
  text("VEEX v11", 70, 105, 1, 1, 1, 1)
end
