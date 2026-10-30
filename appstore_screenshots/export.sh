#!/bin/bash
# Capture raw screenshots on the connected iPhone (USB) and copy them to raw/en-US/.
#   appstore_screenshots/export.sh <device UDID>
set -euo pipefail
cd "$(dirname "$0")/.."
UDID="$1"
OUT=$(mktemp -d)
TEST_RUNNER_STORE_SHOTS=1 xcodebuild test -project BPLog.xcodeproj -scheme BPLog \
  -destination "id=$UDID" -only-testing:BPLogUITests/StoreScreenshots \
  -allowProvisioningUpdates -resultBundlePath "$OUT/shots.xcresult" > "$OUT/log.txt" 2>&1 || { tail -30 "$OUT/log.txt"; exit 1; }
xcrun xcresulttool export attachments --path "$OUT/shots.xcresult" --output-path "$OUT/att" > /dev/null
python3 - "$OUT/att" appstore_screenshots/raw/en-US <<'PY'
import json, shutil, sys, os, re
att, dest = sys.argv[1], sys.argv[2]
for test in json.load(open(os.path.join(att, "manifest.json"))):
    for a in test.get("attachments", []):
        m = re.match(r"(\d\d_[A-Za-z]+)", a.get("suggestedHumanReadableName", ""))
        if m:
            shutil.copy(os.path.join(att, a["exportedFileName"]), os.path.join(dest, m.group(1) + ".png"))
            print("raw:", m.group(1))
PY
