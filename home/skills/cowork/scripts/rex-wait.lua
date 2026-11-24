-- Waits until the program in the target block (rex do -b) ends a turn.
-- A turn ends when the program reports a state other than working, after it
-- reported working. Start the script before you send the member its work,
-- or the working report can arrive before the script listens.
-- Arguments: timeout=<seconds> (default 1800).
local block = rex.block_id
if block == nil then
  error("pass the member block with -b")
end

local deadline = os.time() + (tonumber(rex.args.timeout) or 1800)
local working = false

while true do
  local left = deadline - os.time()
  if left <= 0 then
    return { timed_out = true }
  end
  local ev = rex.wait("terminal.program_status_changed", function(e)
    return e.block_id == block
  end, left)
  if ev == nil then
    return { timed_out = true }
  end
  local record = ev.record or {}
  if record.state == "working" then
    working = true
  elseif working then
    return {
      timed_out = false,
      state = record.state,
      kind = record.kind,
      msg = record.msg,
    }
  end
end
