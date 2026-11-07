local b = BASE or 0
local s = SIZE or 0
local magic = nil
if r32 then magic = r32(b) end
log(string.format("base=%x size=%x magic=%x", b, s, magic or 0))

local n = 0
while true do
  clear()
  text(40, 240, "VEEX OK", 0x00FF00FF, 24)
  text(40, 272, string.format("base %x", b), 0xFFFFFFFF, 12)
  text(40, 290, string.format("size %x", s), 0xFFFFFFFF, 12)
  text(40, 308, string.format("magic %x", magic or 0), 0xFFFFFFFF, 12)
  text(40, 326, "frames " .. n, 0xFFFFFFFF, 12)
  n = n + 1
  msleep(200)
end
