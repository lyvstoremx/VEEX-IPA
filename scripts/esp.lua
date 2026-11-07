local want = {"Player", "RCC_Camera", "TransformGizmo", "GameFacade",
              "PlayerManager", "CameraMode", "Avatar", "PlayerAvatar", "MatchGame"}

for _, w in ipairs(want) do
  local c = i2c_classes(w)
  local exact = false
  for _, n in ipairs(c) do if n == w then exact = true break end end
  log("== " .. w .. " existe=" .. tostring(exact) .. " total=" .. #c)
  if exact then
    local m = i2c_methods(w, "")
    for i = 1, math.min(#m, 90) do log("  " .. m[i]) end
  end
end

log("ptr camera " .. tostring(i2c_ptr("RCC_Camera", "get__camera", 0)))
log("ptr gizmo " .. tostring(i2c_ptr("TransformGizmo", "get_MyCamera", 0)))
log("FIN")

local f = 0
while true do
  clear()
  text(40, 250, "VEEX dump", 0x00FF00FF, 20)
  text(40, 280, "frames " .. f, 0xFFFFFFFF, 12)
  f = f + 1
  msleep(250)
end
