if not i2c_ready or not i2c_ready() then
  log("i2c NO disponible")
else
  log("i2c listo")
  for _, kw in ipairs({"Player", "Camera", "Transform", "Game", "Entity"}) do
    local c = i2c_classes(kw)
    log(kw .. " -> " .. #c)
    for i = 1, math.min(#c, 20) do
      local name = c[i]
      log("CLS " .. name)
      for _, m in ipairs(i2c_methods(name, "pos")) do log("  " .. m) end
      for _, m in ipairs(i2c_methods(name, "get_")) do log("  " .. m) end
    end
  end
  log("FIN dump")
end

local n = 0
while true do
  clear()
  text(40, 250, "VEEX i2c", 0x00FF00FF, 22)
  text(40, 282, "frames " .. n, 0xFFFFFFFF, 12)
  n = n + 1
  msleep(250)
end
