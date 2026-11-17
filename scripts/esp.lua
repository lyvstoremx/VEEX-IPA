local t0 = os.time()
local done = false
local cands = {"Character","Player","Avatar","Entity","Camera","PlayerManager","GameManager","GameFacade","CharacterBase","Match","Weapon","Team"}

function tick()
  if done then return end
  if not i2c_ready() then
    if os.time() - t0 > 15 then done = true log("SIN IL2CPP") end
    return
  end
  done = true
  log("PROBE ON")
  for i = 1, #cands do
    local q = cands[i]
    local t = dump(q, 15)
    log("== "..q.." ("..#t..")")
    for j = 1, #t do log("  ["..t[j].s.."] "..t[j].n) end
  end
  log("PROBE FIN")
end
