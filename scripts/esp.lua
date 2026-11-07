log("VEEX v17")

for i, c in ipairs(i2c_clsall("Object")) do
  local ms = i2c_mnames(c)
  log("O" .. i .. " n=" .. #ms)
  local k = 0
  for _, m in ipairs(ms) do
    if m:lower():find("find") then
      log("  ." .. m)
      k = k + 1
      if k >= 6 then break end
    end
  end
end

local go = i2c_cls("GameObject")
if go then
  local ms = i2c_mnames(go)
  log("GO n=" .. #ms)
  local k = 0
  for _, m in ipairs(ms) do
    if m:lower():find("find") then
      log("  ." .. m)
      k = k + 1
      if k >= 10 then break end
    end
  end
end

function tick()
  clear()
  text("VEEX v17", 70, 105, 1, 1, 1, 1)
end
