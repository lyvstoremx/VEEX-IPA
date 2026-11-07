log("script cargado base=" .. string.format("%x", BASE))

local n = 0
while true do
  clear()
  text(40, 240, "VEEX OK", 0x00FF00FF, 26)
  text(40, 275, "base " .. string.format("%x", BASE), 0xFFFFFFFF, 13)
  text(40, 295, "size " .. string.format("%x", SIZE), 0xFFFFFFFF, 13)
  text(40, 315, "frames " .. n, 0xFFFFFFFF, 13)
  n = n + 1
  msleep(200)
end
