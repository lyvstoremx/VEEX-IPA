log("VEEX v12")

local giz = i2c_ptr("TransformGizmo", "get_MyCamera", 0)
log("giz=" .. tostring(giz))
local cam = nil
if giz then cam = call(giz, 0) end
log("cam=" .. tostring(cam))

if cam and cam ~= 0 then
  local pw = i2c_ptr("Camera", "get_pixelWidth", 0)
  if pw then log("w=" .. tostring(call(pw, cam))) end
end

function tick()
  clear()
  text("VEEX v12", 70, 105, 1, 1, 1, 1)
end
