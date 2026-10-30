# App Store screenshots

1. `export.sh <device UDID>` — runs the `StoreScreenshots` UI test on a USB-connected
   iPhone in `-DEMO` mode (light appearance forced, then restored) and copies the shots
   to `raw/en-US/`.
2. `python3 generate.py` — frames them on the brand blue with headlines → `final/en-US/`
   (1320×2868, the 6.9" size; Apple scales it for smaller iPhones).
3. `~/Documents/projects/kpt-diary/venv/bin/python upload.py` — replaces the version's
   `APP_IPHONE_67` set with `final/en-US/*.png` and uploads `raw/en-US/07_Paywall.png`
   as the In-App Purchase review screenshot.

The paywall is not a store screenshot: it shows the price, which guideline 2.3.7 bars.
