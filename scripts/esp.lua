local jobs = {
  {"Player",    {"pos", "transform", "Team", "HP", "Health", "Name", "Id"}},
  {"Camera",    {"main", "WorldToScreen", "matrix"}},
  {"MatchGame", {"Entity", "Player", "Match"}},
  {"GameFacade",{"Player", "Entity"}},
  {"Transform", {"position", "get_position"}},
}

for _, j in ipairs(jobs) do
  log("### " .. j[1])
  for _, k in ipairs(j[2]) do
    local m = i2c_methods(j[1], k)
    for i = 1, math.min(#m, 20) do log("  " .. m[i]) end
  end
end

local cptr = i2c_ptr("Camera", "get_main", 0)
log("Camera.main ptr " .. tostring(cptr))
if cptr then
  local cam = call(cptr)
  log("Camera.main = " .. tostring(cam))
end
log("FIN2")

local f = 0
while true do
  clear()
  text(40, 250, "VEEX 2", 0x00FF00FF, 20)
  text(40, 280, "frames " .. f, 0xFFFFFFFF, 12)
  f = f + 1
  msleep(250)
end
