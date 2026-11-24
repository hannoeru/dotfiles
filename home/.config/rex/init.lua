rex.bind("cmd+,", "client.settings")
rex.bind("cmd+shift+,", "client.config.reload")
rex.bind("cmd+ctrl+s", "client.sidebar.toggle")
rex.bind("cmd+ctrl+f", "client.window.fullscreen.toggle")

rex.bind("cmd+n", "client.window.new")
rex.bind("cmd+shift+w", "client.window.close")
rex.bind("cmd+t", "client.tab.new")
rex.bind("cmd+w", "pane.close")
rex.bind("cmd+shift+[", "client.tab.previous")
rex.bind("cmd+shift+]", "client.tab.next")
for i = 1, 8 do
  rex.bind("cmd+" .. i, "client.tab.goto", { index = i })
end
rex.bind("cmd+9", "client.tab.goto", { index = -1 })

rex.bind("cmd+c", "pane.copy")
rex.bind("cmd+v", "pane.paste")
rex.bind("cmd+a", "pane.select_all")
rex.bind("cmd+f", "client.find.open")
rex.bind("cmd+g", "client.find.next")
rex.bind("cmd+shift+g", "client.find.previous")
rex.bind("cmd+up", "client.prompt.previous")
rex.bind("cmd+down", "client.prompt.next")

rex.bind("cmd+=", "client.font.increase")
rex.bind("cmd+-", "client.font.decrease")
rex.bind("cmd+0", "client.font.reset")

rex.bind("cmd+d", "pane.split.right")
rex.bind("cmd+shift+d", "pane.split.down")
rex.bind("cmd+[", "pane.focus_previous")
rex.bind("cmd+]", "pane.focus_next")
rex.bind("cmd+shift+enter", "pane.zoom")
rex.bind("cmd+ctrl+=", "pane.balance")
for _, direction in ipairs({ "left", "down", "up", "right" }) do
  rex.bind("cmd+alt+" .. direction, "pane.focus", { direction = direction })
  rex.bind("cmd+ctrl+" .. direction, "pane.resize", { direction = direction })
end

-- rex config check also runs this file. Outside Rex it has no REX_SERVER; inside
-- a Rex terminal the watcher's lock keeps one per server. Require looks beside
-- this file first, so the watcher is there.
if os.getenv("REX_SERVER") then
  local dir = package.path:match("^([^;]*)/%?%.lua;")
  local bin = rex.exec({ "/bin/sh", "-c", "ps -o comm= -p $PPID" }).stdout:match("^(.-)%s*$")
  rex.exec.start(
    { bin, "--autostart=false", "do", dir .. "/agent-resume.lua", "--all" },
    { detach = true, stdout = false, stderr = false }
  )
end
