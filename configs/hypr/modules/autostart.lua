hl.exec_cmd("sh -c 'pgrep -f \"cliphist store\" >/dev/null || { wl-paste --type text --watch cliphist store & wl-paste --type image --watch cliphist store & }'")
hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/wallpaper.sh init")
hl.exec_cmd("hyprctl setcursor Bibata-Modern-Ice 24")
