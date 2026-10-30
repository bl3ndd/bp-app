# App icon

`AppIcon.svg` is the source of `BPLog/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`
(flat #2F5FD0 tile, white logbook, blue heart with a white pulse line; chosen 2026-10-30
over gauge, monogram, drop and tonometer concepts). Re-render at 1024×1024 with no alpha:

    chrome --headless=new --force-device-scale-factor=1 --window-size=1024,1024 \
      --screenshot=AppIcon-1024.png page-with-the-svg.html
