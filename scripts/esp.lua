local b = BASE or 0
local s = SIZE or 0
local magic = nil
if r32 then magic = r32(b) end
log("base=" .. b .. " size=" .. s .. " magic=" .. tostring(magic))

local n = 0
while true do
  clear()
  text(40, 240, "VEEX OK", 0x00FF00FF, 26)
  text(40, 275, "base " .. b, 0xFFFFFFFF, 13)
  text(40, 295, "size " .. s, 0xFFFFFFFF, 13)
  text(40, 315, "magic " .. tostring(magic), 0xFFFFFFFF, 13)
  text(40, 335, "frames " .. n, 0xFFFFFFFF, 13)
  n = n + 1
  msleep(200)
end
