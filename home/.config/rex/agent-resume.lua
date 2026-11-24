local TERMINAL = "com.superlogical.terminal"
local SHELLS = { sh = true, bash = true, zsh = true, fish = true }
local RESUME = {
  claude = { "claude", "--resume" },
  pi = { "pi", "--session" },
}

local function has_transcript(entry)
  if entry.agent == "pi" then
    return rex.exec({ "test", "-s", entry.session }).ok
  end
  return rex.exec({
    "/bin/sh", "-c", 'for f in "$HOME"/.claude/projects/*/"$1".jsonl; do [ -s "$f" ] && exit 0; done; exit 1',
    "sh", entry.session,
  }).ok
end

local state_dir = (os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")) .. "/rex-agent-sessions"
local snapshot_path = state_dir .. "/snapshot.json"

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
  local tmp = path .. ".tmp"
  local f = assert(io.open(tmp, "w"))
  f:write(data)
  f:close()
  assert(os.rename(tmp, path))
end

local function quote(word)
  return "'" .. word:gsub("'", "'\\''") .. "'"
end

local function read_record(block_id)
  local data = read_file(state_dir .. "/" .. block_id:gsub("^block:", ""))
  if not data then return nil end
  local agent, session, cwd, pid = data:match("^([^\n]*)\n([^\n]*)\n([^\n]*)\n([^\n]*)")
  if not RESUME[agent] then return nil end
  return { agent = agent, session = session, cwd = cwd, pid = tonumber(pid) }
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
  local list = rex.call("session.list") or {}
  for _, session in ipairs(list.sessions or {}) do
    attach(session.session_id)
    local view = rex.call("session.view", { session_id = session.session_id }) or {}
    for _, window in ipairs(view.windows or {}) do
      for _, layer in ipairs(window.layers or {}) do
        for _, block in ipairs(layer.blocks or {}) do
          if block.creator_name == TERMINAL then
            out[block.block_id] = session.session_id
          end
        end
      end
    end
  end
  return out
end

local function foreground(block_id, session_id)
  attach(session_id)
  local process = rex.block.call(TERMINAL, "process", { block_id = block_id, session_id = session_id })
  return process and process.foreground
end

local last_saved
local function save(instance)
  local agents = {}
  for block_id, session_id in pairs(panes()) do
    local record = read_record(block_id)
    local fg = record and foreground(block_id, session_id)
    if fg and fg.pid == record.pid then
      agents[#agents + 1] = { block_id = block_id, agent = record.agent, session = record.session, cwd = record.cwd }
    end
  end
  local encoded = rex.json.encode(agents)
  if encoded == last_saved then return end
  write_file(snapshot_path, rex.json.encode({ instance = instance, saved_at = os.time(), agents = agents }))
  last_saved = encoded
end

local function wait_for_shell(block_id)
  for _ = 1, 120 do
    local session_id = panes()[block_id]
    local fg = session_id and foreground(block_id, session_id)
    if fg and SHELLS[fg.name] then return session_id end
    rex.sleep(0.25)
  end
end

local function resume(instance)
  local data = read_file(snapshot_path)
  local snapshot = data and rex.json.decode(data)
  if not snapshot or snapshot.instance == instance then return end
  for _, entry in ipairs(snapshot.agents or {}) do
    local label = entry.agent .. " " .. entry.session .. " in " .. entry.block_id
    local session_id = has_transcript(entry) and wait_for_shell(entry.block_id)
    if session_id then
      local argv = RESUME[entry.agent]
      local line = "cd -- " .. quote(entry.cwd) .. " && " .. argv[1] .. " " .. argv[2] .. " " .. quote(entry.session)
      rex.block.call(TERMINAL, "write", { block_id = entry.block_id, session_id = session_id, data = "\5\21" .. line .. "\r" })
      log("resumed " .. label)
    else
      log("skipped " .. label .. ": no conversation yet, or no shell in the pane")
    end
  end
end

rex.exec({ "mkdir", "-p", state_dir })
local instance = rex.call("server.status").instance_id
local ok, err = pcall(resume, instance)
if not ok then log("resume failed: " .. tostring(err)) end

local pending
local function save_soon(delay)
  if pending then return end
  pending = rex.after(delay, function()
    pending = nil
    local saved, why = pcall(save, instance)
    if not saved then log("save failed: " .. tostring(why)) end
  end)
end

rex.on("terminal.process_changed", function() save_soon(2) end)
rex.on("block_closed", function() save_soon(2) end)
rex.every(10, function() save_soon(0) end)
save_soon(0)
