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

rex.bind("ctrl+b>ctrl+b", "pane.send_key", { key = "ctrl+b" })

rex.bind("ctrl+b>s", "client.settings")
rex.bind("ctrl+b>shift+r", "client.config.reload")
rex.bind("ctrl+b>b", "client.sidebar.toggle")

rex.bind("ctrl+b>shift+n", "session.new")
rex.bind("ctrl+b>shift+w", "session.rename")
rex.bind("ctrl+b>w", "session.switch")
rex.bind("ctrl+b>g", "pane.go_to")

rex.bind("ctrl+b>c", "client.tab.new")
rex.bind("ctrl+b>shift+t", "client.tab.rename")
rex.bind("ctrl+b>shift+x", "client.tab.close")
rex.bind("ctrl+b>p", "client.tab.previous")
rex.bind("ctrl+b>n", "client.tab.next")
for i = 1, 9 do
  rex.bind("ctrl+b>" .. i, "client.tab.goto", { index = i })
end

rex.bind("ctrl+b>v", "pane.split.right")
rex.bind("ctrl+b>-", "pane.split.down")
rex.bind("ctrl+b>x", "pane.close")
rex.bind("ctrl+b>z", "pane.zoom")
rex.bind("ctrl+b>[", "pane.copy_mode.enter")
rex.bind("ctrl+b>tab", "pane.focus_next")
rex.bind("ctrl+b>shift+tab", "pane.focus_previous")

local directions = { h = "left", j = "down", k = "up", l = "right" }
for key, direction in pairs(directions) do
  rex.bind("ctrl+b>" .. key, "pane.focus", { direction = direction })
  rex.bind("ctrl+b>shift+" .. key, "pane.move", { direction = direction })
end

rex.mode("resize", { exclusive = true })
rex.bind("ctrl+b>r", "client.mode.enter", { name = "resize" })
for key, direction in pairs(directions) do
  rex.bind("resize/" .. key, "pane.resize", { direction = direction })
  rex.bind("resize/" .. direction, "pane.resize", { direction = direction })
end
rex.bind("resize/enter", "client.mode.exit")
