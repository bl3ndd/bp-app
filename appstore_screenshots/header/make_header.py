"""App Store product page header (Header and Search Results): 3840x1646 and 5244x2950.

    python3 appstore_screenshots/header/make_header.py
Brand blue background, icon + name + tagline on the left, two app screens on the
right. Key content stays inside the middle ~70% so device crops don't cut it.
"""
import base64, os, subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

def b64(path):
    return "data:image/png;base64," + base64.b64encode(open(path, "rb").read()).decode()

ICON = b64(os.path.join(ROOT, "..", "BPLog", "Assets.xcassets", "AppIcon.appiconset", "AppIcon-1024.png"))
HOME = b64(os.path.join(ROOT, "raw", "en-US", "01_Home.png"))
STATS = b64(os.path.join(ROOT, "raw", "en-US", "05_StatsMore.png"))

def html(w, h):
    u = h / 1646  # scale unit from the 3840x1646 layout
    return f"""<!doctype html><html><head><meta charset="utf-8"><style>
* {{ margin:0; padding:0; box-sizing:border-box; }}
html,body {{ width:{w}px; height:{h}px; overflow:hidden; }}
body {{
  font-family:'SF Pro Rounded','SF Pro Display',-apple-system,sans-serif;
  background-color:#2F5FD0;
  background-image:
    radial-gradient(at 10% 15%, rgba(96,140,240,0.95) 0px, transparent 45%),
    radial-gradient(at 92% 10%, rgba(70,110,225,0.85) 0px, transparent 40%),
    radial-gradient(at 80% 95%, rgba(30,58,138,0.95) 0px, transparent 50%),
    radial-gradient(at 5% 90%, rgba(37,75,180,0.90) 0px, transparent 45%);
  display:flex; align-items:center; justify-content:center; gap:{220*u}px;
}}
.text {{ width:{1250*u}px; color:#fff; }}
.brand {{ display:flex; align-items:center; gap:{44*u}px; }}
.brand img {{ width:{220*u}px; height:{220*u}px; border-radius:{50*u}px; box-shadow:0 {20*u}px {50*u}px rgba(8,20,60,0.35); }}
.brand h1 {{ font-size:{150*u}px; font-weight:800; letter-spacing:{-3*u}px; }}
.tag {{ margin-top:{70*u}px; font-size:{96*u}px; font-weight:700; line-height:1.1; letter-spacing:{-2*u}px; }}
.sub {{ margin-top:{40*u}px; font-size:{52*u}px; font-weight:500; color:rgba(255,255,255,0.85); }}
.phones {{ display:flex; align-items:center; gap:{70*u}px; }}
.phone {{ width:{560*u}px; border-radius:{70*u}px; background:#0E1117; padding:{11*u}px;
  box-shadow:0 {50*u}px {90*u}px rgba(8,20,60,0.45), 0 {14*u}px {32*u}px rgba(8,20,60,0.30); }}
.phone img {{ width:100%; display:block; border-radius:{60*u}px; }}
.phone.back {{ transform:translateY({70*u}px); }}
</style></head><body>
  <div class="text">
    <div class="brand"><img src="{ICON}"><h1>Simply BP</h1></div>
    <div class="tag">Your blood pressure,<br>logged in seconds</div>
    <div class="sub">Daily averages, trends and a report your doctor can read</div>
  </div>
  <div class="phones">
    <div class="phone"><img src="{HOME}"></div>
    <div class="phone back"><img src="{STATS}"></div>
  </div>
</body></html>"""

for w, h in [(3840, 1646), (5244, 2950)]:
    hp = os.path.join(HERE, f"header_{w}x{h}.html")
    open(hp, "w").write(html(w, h))
    out = os.path.join(HERE, f"header_{w}x{h}.png")
    subprocess.run([CHROME, "--headless", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1",
                    "--virtual-time-budget=4000", f"--screenshot={out}", f"--window-size={w},{h}", f"file://{hp}"],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    os.remove(hp)
    print("ok", os.path.basename(out))
