log("VEEX v18")

local function pickmax(name)
  local best, bn = nil, -1
  for _, c in ipairs(i2c_clsall(name)) do
    local n = #i2c_mnames(c)
    if n > bn then best, bn = c, n end
  end
  return best, bn
end

local P, pn = pickmax("Player")
log("P n=" .. pn)

local O = nil
for _, c in ipairs(i2c_clsall("Object")) do
  for _, m in ipairs(i2c_mnames(c)) do
    if m == "FindObjectsOfType" then O = c break end
  end
  if O then break end
end
log("O=" .. tostring(O))

if O and P then
  local fot = i2c_mptr(O, "FindObjectsOfType", 1)
  log("fot=" .. tostring(fot))
  if fot then
    local t = clstype(P)
    log("type=" .. tostring(t))
    if t then
      local arr = callv(fot, 0, t)
      log("arr=" .. tostring(arr))
      if arr and arr ~= 0 then
        local n = arrlen(arr)
        log("n=" .. n)
        if n > 0 then
          local e = arrat(arr, 0)
          log("e0=" .. tostring(e))
          if e and e ~= 0 then
            local gn = i2c_mptr(P, "get_NickName", 0)
            if gn then
              local np = call(gn, e)
              if np and np ~= 0 then log("nick0=" .. str(np)) end
            end
          end
        end
      end
    end
  end
end

function tick()
  clear()
  text("VEEX v18", 70, 105, 1, 1, 1, 1)
end
