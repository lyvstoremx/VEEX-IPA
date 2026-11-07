log("VEEX v14")

local m = i2c_ptr("Camera", "get_main", 0)
local c = nil
if m then c = call(m, 0) end
if not c or c == 0 then
  local cur = i2c_ptr("Camera", "get_current", 0)
  if cur then c = call(cur, 0) end
end
log("cam=" .. tostring(c))

if c and c ~= 0 then
  local pw = i2c_ptr("Camera", "get_pixelWidth", 0)
  if pw then log("w=" .. tostring(call(pw, c))) end
end

function tick()
  clear()
  text("VEEX v14", 70, 105, 1, 1, 1, 1)
end
