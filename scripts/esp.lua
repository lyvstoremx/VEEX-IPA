log("VEEX v61 attest")

local pats = { "attest", "ginclient", "damdm", "jail", "antidata", "antihack", "verify" }
local seen = {}
local found = {}
for _, cn in ipairs(i2c_classes()) do
  local l = cn:lower()
  local hit = false
  for _, p in ipairs(pats) do
    if l:find(p) then hit = true break end
  end
  if not hit and l:sub(1, 3) == "gin" then hit = true end
  if hit and not seen[cn] then
    seen[cn] = true
    found[#found + 1] = cn
    log("C " .. cn)
    if #found >= 40 then break end
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
      if k >= 40 then break end
    end
  end
end
log("FIN")

function tick()
  clear()
  text("v61", 10, 120, 0.6, 1, 0.6, 1)
end
