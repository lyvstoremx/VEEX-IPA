log("VEEX v10")

local cam = i2c_ptr("Camera", "get_main", 0)
log("main=" .. tostring(cam))
if cam then
  local c = call(cam, 0)
  log("cam=" .. tostring(c))
  if c and c ~= 0 then
    local pw = i2c_ptr("Camera", "get_pixelWidth", 0)
    if pw then log("w=" .. tostring(call(pw, c))) end
  end
end

function tick()
  clear()
  text("VEEX v10", 70, 105, 1, 1, 1, 1)
end
