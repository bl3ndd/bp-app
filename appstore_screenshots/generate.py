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

Run:  python3 generate.py      Requires: Google Chrome, Python 3 (no pip deps).
"""
import base64, os, subprocess

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
    ("05_StatsMore.png", "Watch your days<br>in range grow", "Days by category, morning vs. evening"),
    # No paywall shot: it shows the price, and 2.3.7 bars prices in screenshots.
    # raw/en-US/07_Paywall.png is the In-App Purchase review screenshot instead.
]

# Brand: the icon's flat blue (#2F5FD0) with lighter and deeper blues in the mesh.
TEMPLATE = """<!doctype html><html><head><meta charset="utf-8"><style>
* { margin:0; padding:0; box-sizing:border-box; }
html,body { width:1320px; height:2868px; overflow:hidden; }
body {
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
</style></head><body>
  <div class="head"><h1>__HEAD__</h1><p>__SUB__</p></div>
  <div class="phone"><img src="__IMG__"></div>
</body></html>"""


def b64(path):
    with open(path, "rb") as f:
        return "data:image/png;base64," + base64.b64encode(f.read()).decode()


def render(lang, fname, head, sub, outname):
    src = os.path.join(RAW, lang, fname)
    if not os.path.exists(src):
        print("  SKIP (no raw):", src); return
    outdir = os.path.join(FINAL, lang); os.makedirs(outdir, exist_ok=True)
    html = (TEMPLATE.replace("__IMG__", b64(src))
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
