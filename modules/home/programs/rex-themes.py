import json
import plistlib
import subprocess
import sys
import time

DOMAIN = "com.superlogical.rex"
KEY = "Workspace.customThemes"
# Rex stores createdAt as seconds since 2001-01-01, the Apple reference date.
APPLE_EPOCH = 978307200
XTERM_STEPS = [0, 95, 135, 175, 215, 255]


def color(value):
    value = value.lstrip("#")
    red, green, blue = (int(value[i:i + 2], 16) / 255 for i in (0, 2, 4))
    return {"red": red, "green": green, "blue": blue, "alpha": 1, "colorSpace": "srgb"}


def xterm(index):
    if index < 232:
        index -= 16
        rgb = (XTERM_STEPS[index // 36], XTERM_STEPS[index // 6 % 6], XTERM_STEPS[index % 6])
    else:
        rgb = (8 + 10 * (index - 232),) * 3
    return "#%02x%02x%02x" % rgb


def read_ghostty_theme(path):
    theme = {}
    ansi = {}
    with open(path) as theme_file:
        for line in theme_file:
            key, _, value = (part.strip() for part in line.partition("="))
            if key == "palette":
                index, _, value = value.partition("=")
                ansi[int(index)] = value
            elif key:
                theme[key] = value
    theme["palette"] = ansi
    return theme


def palette(theme):
    ansi = theme["palette"]
    return {
        "background": color(theme["background"]),
        "foreground": color(theme["foreground"]),
        "cursor": color(theme["cursor-color"]),
        "cursorText": color(theme["cursor-text"]),
        "selectionBackground": color(theme["selection-background"]),
        "selectionForeground": color(theme["selection-foreground"]),
        "ansi": [color(ansi[i]) for i in range(16)],
        "paletteBase": {str(i): color(xterm(i)) for i in range(16, 256)},
        "paletteGenerate": False,
        "paletteHarmonious": False,
        "paletteOverrides": {},
    }


def stored_themes():
    exported = subprocess.run(
        ["/usr/bin/defaults", "export", DOMAIN, "-"],
        check=True,
        capture_output=True,
    ).stdout
    data = plistlib.loads(exported).get(KEY)
    return json.loads(data) if data else []


def main():
    with open(sys.argv[1]) as spec_file:
        specs = json.load(spec_file)
    themes = stored_themes()
    updated = list(themes)
    for spec in specs:
        index = next((i for i, t in enumerate(updated) if t["id"] == spec["id"]), None)
        entry = {
            "id": spec["id"],
            "name": spec["name"],
            "appearance": spec["appearance"],
            "source": {"ghosttyFile": {"fileName": spec["fileName"]}},
            "createdAt": time.time() - APPLE_EPOCH if index is None else updated[index]["createdAt"],
            "palette": palette(read_ghostty_theme(spec["path"])),
        }
        if index is None:
            updated.append(entry)
        else:
            updated[index] = entry
    if updated != themes:
        print(json.dumps(updated).encode().hex())


if __name__ == "__main__":
    main()
