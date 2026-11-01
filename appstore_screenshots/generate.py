#!/usr/bin/env python3
"""
Simply BP App Store screenshots (from the appstore-screenshots skill template).
App Store marketing-screenshot generator — HTML/CSS + headless Chrome.

Copy this into the project (e.g. appstore_screenshots/generate.py) and ADAPT:
  1. the mesh-gradient RGBs in TEMPLATE  -> the app's brand colors
  2. the headline color (--head)         -> a dark brand tone
  3. the SCREENS list                    -> your screens + RU/EN copy
  4. sizes (1320x2868 = iPhone 6.9")     -> only change for other device sizes

Layout:
  raw/<lang>/NN_Screen.png    -> source (plain app screenshot, 1320x2868)
  final/<lang>/NN_Screen.png  -> output (background + headline + device frame)

Run:  python3 generate.py      Requires: Google Chrome, Python 3 with Pillow.
"""
import base64, io, os, subprocess

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw")
FINAL = os.path.join(HERE, "final")
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

# (file, head, sub). <br> controls line breaks. Benefit-driven copy, NO medical
# claims and no prices (guidelines 1.4.1, 2.3.7). English only: the app is en-US.
SCREENS = [
    ("01_Home.png", "Your blood pressure,<br>logged in seconds", "Simple, clear, no clutter"),
    ("02_AddReading.png", "See where you stand<br>as you type", "Color-coded from Normal to Crisis"),
    ("06_Report.png", "A report your<br>doctor can read", "Summary, chart and every reading in one PDF"),
    ("03_Charts.png", "See your trend<br>at a glance", "One point per day, even with several readings"),
    ("04_Stats.png", "Know your<br>real averages", "Trends, changes and more"),
    ("05_History.png", "Every reading,<br>easy to find", "Search by number, tag or note"),
    # No paywall shot: it shows the price, and 2.3.7 bars prices in screenshots.
    # raw/en-US/07_Paywall.png is the In-App Purchase review screenshot instead.
]

# Brand: the icon's flat blue (#2F5FD0) with lighter and deeper blues in the mesh.
TEMPLATE = """<!doctype html><html><head><meta charset="utf-8"><style>
* { margin:0; padding:0; box-sizing:border-box; }
html,body { width:1320px; height:2868px; overflow:hidden; }
body {
  position:relative;
  font-family:'SF Pro Rounded','SF Pro Display',-apple-system,sans-serif;
  background-color:#2F5FD0;
  background-image:
    radial-gradient(at 12% 10%, rgba(96,140,240,0.95) 0px, transparent 48%),
    radial-gradient(at 90% 14%, rgba(70,110,225,0.85) 0px, transparent 44%),
    radial-gradient(at 85% 88%, rgba(30,58,138,0.95) 0px, transparent 52%),
    radial-gradient(at 6% 84%, rgba(37,75,180,0.90) 0px, transparent 48%);
  display:flex; flex-direction:column; align-items:center;
}
.head { margin-top:150px; text-align:center; padding:0 70px; }
.head h1 { font-size:100px; font-weight:800; line-height:1.07; letter-spacing:-2px; color:#FFFFFF; }
.head p  { font-size:46px; font-weight:500; margin-top:34px; color:rgba(255,255,255,0.82); letter-spacing:-0.3px; }
.phone {
  margin-top:90px; width:1000px; border-radius:110px; background:#0E1117; padding:16px;
  box-shadow: 0 70px 120px rgba(8,20,60,0.45), 0 20px 44px rgba(8,20,60,0.30);
}
.phone img { width:100%; display:block; border-radius:94px; }
.screen { position:relative; }
.screen svg { position:absolute; inset:0; width:100%; height:100%; }
.zoom {
  position:absolute; left:60px; right:60px; top:1050px; border-radius:36px; overflow:hidden;
  box-shadow: 0 50px 100px rgba(8,20,60,0.45), 0 14px 34px rgba(8,20,60,0.28);
}
.zoom img { width:100%; display:block; }
</style></head><body>
  <div class="head"><h1>__HEAD__</h1><p>__SUB__</p></div>
  <div class="phone"><div class="screen"><img src="__IMG__">__STATUS__</div></div>
  __ZOOM__
</body></html>"""

# Real-device captures carry the real clock and battery. Paint Apple's 9:41,
# full signal and a full battery over them (raw pixel coordinates, 1206 wide).
STATUS = """<svg viewBox="0 0 1206 2622" preserveAspectRatio="none">
  <rect x="130" y="55" width="190" height="80" fill="__BG__"/>
  <rect x="850" y="60" width="85" height="70" fill="__BG__"/>
  <rect x="1005" y="60" width="110" height="70" fill="__BG__"/>
  <rect x="938" y="66" width="64" height="58" fill="__BG__"/>
  <path d="M970,116 L959.4,105.4 A15,15 0 0 1 980.6,105.4 Z"/>
  <path d="M953.7,98.7 A23,23 0 0 1 986.3,98.7" fill="none" stroke="#000" stroke-width="8.5" stroke-linecap="round"/>
  <path d="M945.2,89.2 A35,35 0 0 1 994.8,89.2" fill="none" stroke="#000" stroke-width="8.5" stroke-linecap="round"/>
  <text x="222" y="117" text-anchor="middle" font-family="SF Pro Text, -apple-system" font-weight="600" font-size="57">9:41</text>
  <rect x="865" y="104" width="11" height="13" rx="3"/><rect x="880.5" y="96" width="11" height="21" rx="3"/>
  <rect x="896" y="88" width="11" height="29" rx="3"/><rect x="911" y="79" width="11" height="38" rx="3"/>
  <rect x="1019.5" y="80.5" width="71" height="35" rx="11" fill="none" stroke="#000" stroke-opacity="0.35" stroke-width="3"/>
  <rect x="1025" y="86" width="60" height="24" rx="6.5"/>
  <rect x="1094" y="91" width="5" height="14" rx="2.5" fill-opacity="0.4"/>
</svg>"""

# The report page is unreadable at phone scale: show its top (summary + chart) enlarged.
ZOOM = {"06_Report.png": (52, 400, 1154, 1430)}


def b64(path):
    with open(path, "rb") as f:
        return "data:image/png;base64," + base64.b64encode(f.read()).decode()


def render(lang, fname, head, sub, outname):
    src = os.path.join(RAW, lang, fname)
    if not os.path.exists(src):
        print("  SKIP (no raw):", src); return
    outdir = os.path.join(FINAL, lang); os.makedirs(outdir, exist_ok=True)
    im = Image.open(src).convert("RGB")
    bg = "#%02x%02x%02x" % im.getpixel((600, 20))
    zoom = ""
    if fname in ZOOM:
        buf = io.BytesIO()
        im.crop(ZOOM[fname]).save(buf, "PNG")
        zoom = '<div class="zoom"><img src="data:image/png;base64,' + base64.b64encode(buf.getvalue()).decode() + '"></div>'
    html = (TEMPLATE.replace("__IMG__", b64(src)).replace("__STATUS__", STATUS.replace("__BG__", bg))
                    .replace("__ZOOM__", zoom)
                    .replace("__HEAD__", head).replace("__SUB__", sub))
    hp = os.path.join(outdir, outname.replace(".png", ".html"))
    with open(hp, "w") as f:
        f.write(html)
    out = os.path.join(outdir, outname)
    subprocess.run([CHROME, "--headless", "--disable-gpu", "--hide-scrollbars",
                    "--force-device-scale-factor=1", "--virtual-time-budget=4000",
                    f"--screenshot={out}", "--window-size=1320,2868", f"file://{hp}"],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    os.remove(hp)
    print("  ok", lang, "->", os.path.relpath(out, HERE))


def main():
    for i, (fname, head, sub) in enumerate(SCREENS, 1):
        render("en-US", fname, head, sub, f"{i:02d}_{fname[3:]}")
    print("done. finals in", os.path.relpath(FINAL, HERE))


if __name__ == "__main__":
    main()
