log("VEEX v62 checkers")

local pats = { "anti", "check", "detect", "jail", "attest", "integrity",
               "tamper", "memcheck", "memcheck", "secure", "sign", "device" }
local seen, found = {}, {}
for _, cn in ipairs(i2c_classes()) do
  local l = cn:lower()
  local hit = false
  for _, p in ipairs(pats) do
    if l:find(p, 1, true) then hit = true break end
  end
  if hit and not seen[cn] then
    seen[cn] = true
    found[#found + 1] = cn
    log("C " .. cn)
    if #found >= 120 then break end
  end
end
log("NC=" .. #found)

for i = 1, #found do
  local c = i2c_cls(found[i])
  if c then
    local k = 0
    for _, m in ipairs(i2c_mnames(c)) do
      log("M " .. found[i] .. "." .. m)
      k = k + 1
      if k >= 30 then break end
    end
  end
end
log("FIN")

function tick()
  clear()
  text("v62", 10, 120, 0.6, 1, 0.6, 1)
end
