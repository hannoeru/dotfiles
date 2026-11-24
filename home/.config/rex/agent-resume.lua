local TERMINAL = "com.superlogical.terminal"
local SHELLS = { sh = true, bash = true, zsh = true, fish = true }
local RESUME = {
  claude = { "claude", "--resume" },
  pi = { "pi", "--session" },
}
local RESUME_WITHIN = 120

local state_dir = (os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")) .. "/rex-agent-sessions"

local function log(message)
  local f = io.open(state_dir .. "/agent-resume.log", "a")
  if f then
    f:write(os.date("%Y-%m-%d %H:%M:%S "), message, "\n")
    f:close()
  end
end

local function read_file(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local data = f:read("*a")
  f:close()
  return data
end

local function write_file(path, data)
  local f = assert(io.open(path, "w"))
  f:write(data)
  f:close()
end

local function quote(word)
  return "'" .. word:gsub("'", "'\\''") .. "'"
end

local function alive(pid)
  return pid ~= nil and rex.exec({ "kill", "-0", tostring(pid) }).ok
end

local function record_path(block_id)
  return state_dir .. "/" .. block_id:gsub("^block:", "")
end

local function read_record(block_id)
  local data = read_file(record_path(block_id))
  if not data then return nil end
  local agent, session, cwd, pid = data:match("^([^\n]*)\n([^\n]*)\n([^\n]*)\n([^\n]*)")
  if not RESUME[agent] then return nil end
  return { block_id = block_id, agent = agent, session = session, cwd = cwd, pid = tonumber(pid) }
end

local function has_transcript(record)
  if record.agent == "pi" then
    return rex.exec({ "test", "-s", record.session }).ok
  end
  return rex.exec({
    "/bin/sh", "-c", 'for f in "$HOME"/.claude/projects/*/"$1".jsonl; do [ -s "$f" ] && exit 0; done; exit 1',
    "sh", record.session,
  }).ok
end

-- os.time reads a table as local time; server.status gives UTC.
local function parse_utc(text)
  local y, mo, d, h, mi, s = (text or ""):match("^(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
  if not y then return nil end
  local t = os.time({ year = y, month = mo, day = d, hour = h, min = mi, sec = s })
  return t + (t - os.time(os.date("!*t", t)))
end

local attached = {}
local function attach(session_id)
  if not attached[session_id] then
    rex.call("session.attach", { session_id = session_id })
    attached[session_id] = true
  end
end

local function panes()
  local out = {}
  for _, session in ipairs((rex.call("session.list") or {}).sessions or {}) do
    attach(session.session_id)
    local view = rex.call("session.view", { session_id = session.session_id }) or {}
    for _, window in ipairs(view.windows or {}) do
      for _, layer in ipairs(window.layers or {}) do
        for _, block in ipairs(layer.blocks or {}) do
          if block.creator_name == TERMINAL then out[block.block_id] = session.session_id end
        end
      end
    end
  end
  return out
end

local function wait_for_shell(block_id, session_id)
  for _ = 1, 40 do
    local process = rex.block.call(TERMINAL, "process", { block_id = block_id, session_id = session_id })
    local fg = process and process.foreground
    if fg and SHELLS[fg.name] then return true end
    rex.sleep(0.25)
  end
  return false
end

local function resume(status)
  local marker = state_dir .. "/resumed-instance"
  if read_file(marker) == status.instance_id then return end
  write_file(marker, status.instance_id)
  local started = parse_utc(status.started_at)
  if not started or os.time() - started > RESUME_WITHIN then
    return log("not resuming: server " .. status.instance_id .. " did not start just now")
  end

  local live = panes()
  -- Rex returns nil for a rex.exec called inside a for-in header, so call it first.
  local names = rex.exec({ "ls", state_dir }).stdout
  for name in names:gmatch("[^\n]+") do
    local block_id = "block:" .. name
    local record = read_record(block_id)
    local session_id = live[block_id]
    if record and not session_id then
      os.remove(record_path(block_id))
    elseif record and not alive(record.pid) then
      local label = record.agent .. " " .. record.session .. " in " .. block_id
      if not has_transcript(record) then
        log("skipped " .. label .. ": no conversation yet")
      elseif not wait_for_shell(block_id, session_id) then
        log("skipped " .. label .. ": no shell in the pane")
      else
        local argv = RESUME[record.agent]
        local line = "cd -- " .. quote(record.cwd) .. " && " .. argv[1] .. " " .. argv[2] .. " " .. quote(record.session)
        rex.block.call(TERMINAL, "write", { block_id = block_id, session_id = session_id, data = line .. "\r" })
        log("resumed " .. label)
      end
    end
  end
end

-- One watcher per server instance: config reloads start this script again.
local function take_lock(instance)
  local lock = state_dir .. "/watcher-" .. instance
  local holder = tonumber(read_file(lock) or "")
  if alive(holder) then return false end
  local own = tonumber(rex.exec({ "/bin/sh", "-c", "echo $PPID" }).stdout)
  write_file(lock, tostring(own))
  rex.exec({ "/bin/sh", "-c", 'for f in "$1"/watcher-*; do [ "$f" = "$2" ] || rm -f -- "$f"; done', "sh", state_dir, lock })
  return true
end

rex.exec({ "mkdir", "-p", state_dir })
local status = rex.call("server.status")
if not take_lock(status.instance_id) then return rex.stop(0) end

local ok, err = pcall(resume, status)
if not ok then log("resume failed: " .. tostring(err)) end

-- Herdr's rule: a pane forgets its agent when the agent exits and the shell is
-- back in front. A server stop sends no such event, so its records survive.
rex.on("terminal.process_changed", function(_, ev)
  local fg = ev.foreground
  local record = fg and SHELLS[fg.name] and read_record(ev.block_id)
  if record and not alive(record.pid) then os.remove(record_path(ev.block_id)) end
end)

rex.on("block_closed", function(_, ev)
  if ev.block_id then os.remove(record_path(ev.block_id)) end
end)
