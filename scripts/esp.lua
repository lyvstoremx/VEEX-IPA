local t0 = os.time()
local done = false
local cands = {"Player","Avatar","Character","Pawn","Actor","Entity","Camera","MainPlayer","LocalPlayer","Human"}

function tick()
  if done then return end
  if not i2c_ready() then
    if os.time() - t0 > 20 then done = true log("SIN IL2CPP") end
    return
  end
  done = true
  log("PROBE2 ON")
  for i = 1, #cands do
    local q = cands[i]
    local t = dump(q, 6000)
    local ex, cow = 0, 0
    for j = 1, #t do
      local e = t[j]
      local ns = e.s or ""
      local nm = e.n or ""
      if nm == q then
        ex = ex + 1
        log("EX ["..ns.."] "..nm.." @"..string.format("%x", e.p))
      elseif string.find(ns, "COW") and cow < 25 then
        cow = cow + 1
        log("C ["..ns.."] "..nm)
      end
    end
    log("== "..q.." total="..#t.." exact="..ex.." cow="..cow)
  end
  log("PROBE2 FIN")
end
