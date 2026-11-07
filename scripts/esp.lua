local b = BASE or 0
local s = SIZE or 0
local magic = r32 and r32(b)
log(string.format("base=%x size=%x magic=%x", b, s, magic or 0))

local path = DOC .. "/ref.dylib"
local len = flen and flen(path) or 0
log("ref bytes " .. len)

local seen = {}
local hits = 0
local scans = 0
local off = 0
while off < len and hits < 40 and scans < 400 do
  local chunk = fread(path, off, 65536)
  if not chunk or #chunk == 0 then break end
  for run in chunk:gmatch("[%x%? ]+") do
    if #run >= 14 and #run <= 64 and scans < 400 then
      local ok, np = true, 0
      for tok in run:gmatch("%S+") do
        if #tok ~= 2 or not tok:match("^[%x%?][%x%?]$") then ok = false break end
        np = np + 1
      end
      if ok and np >= 6 and not seen[run] then
        seen[run] = true
        scans = scans + 1
        if scan(run) then hits = hits + 1; log("HIT " .. run) end
      end
    end
  end
  off = off + 65536
end
log(string.format("fin hits=%d scans=%d", hits, scans))

local n = 0
while true do
  clear()
  text(40, 236, "VEEX OK", 0x00FF00FF, 22)
  text(40, 264, string.format("magic %x", magic or 0), 0xFFFFFFFF, 12)
  text(40, 282, string.format("hits %d  scans %d", hits, scans), 0xFFFFFFFF, 12)
  text(40, 300, "frames " .. n, 0xFFFFFFFF, 12)
  n = n + 1
  msleep(200)
end
