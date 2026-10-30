"""Upload store screenshots and the IAP review screenshot to App Store Connect.

    ~/Documents/projects/kpt-diary/venv/bin/python appstore_screenshots/upload.py

Replaces whatever is there (re-running never duplicates). Reuses Mezame's API
client and key config, like scripts/asc_fill.py.
"""
import glob
import hashlib
import os
import sys
import urllib.request

sys.path.insert(0, os.path.expanduser("~/Documents/projects/kpt-diary/scripts/asc_l10n"))
import asc  # noqa: E402

APP_ID = "6828866713"
HERE = os.path.dirname(os.path.abspath(__file__))
DISPLAY_TYPE = "APP_IPHONE_67"  # takes 1320x2868 (6.9"), as Mezame's sets do


def ok(label, status, payload):
    if not 200 <= status < 300:
        sys.exit(f"ERR {label} ({status}) {asc.errmsg(payload)}")
    return payload


def put_parts(operations, data):
    for op in operations:
        chunk = data[op["offset"]:op["offset"] + op["length"]]
        req = urllib.request.Request(op["url"], data=chunk, method=op["method"])
        for h in op.get("requestHeaders", []):
            req.add_header(h["name"], h["value"])
        urllib.request.urlopen(req, timeout=120).read()


def upload(kind, attributes_create, relationships, path):
    """Reserve → PUT bytes → commit with checksum, for any ASC asset type."""
    data = open(path, "rb").read()
    reservation = ok(f"reserve {os.path.basename(path)}", *asc.req("POST", f"/v1/{kind}", {"data": {
        "type": kind, "attributes": {"fileName": os.path.basename(path), "fileSize": len(data), **attributes_create},
        "relationships": relationships}}))["data"]
    put_parts(reservation["attributes"]["uploadOperations"], data)
    ok(f"commit {os.path.basename(path)}", *asc.req("PATCH", f"/v1/{kind}/{reservation['id']}", {"data": {
        "type": kind, "id": reservation["id"],
        "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}}))
    print("  uploaded", os.path.basename(path))


def store_screenshots():
    _, versions = asc.req("GET", f"/v1/apps/{APP_ID}/appStoreVersions?filter[appStoreState]=PREPARE_FOR_SUBMISSION")
    version_id = versions["data"][0]["id"]
    _, locs = asc.req("GET", f"/v1/appStoreVersions/{version_id}/appStoreVersionLocalizations")
    loc_id = next(l["id"] for l in locs["data"] if l["attributes"]["locale"] == "en-US")
    _, sets = asc.req("GET", f"/v1/appStoreVersionLocalizations/{loc_id}/appScreenshotSets")
    shot_set = next((s for s in sets["data"] if s["attributes"]["screenshotDisplayType"] == DISPLAY_TYPE), None)
    if shot_set is None:
        shot_set = ok("create set", *asc.req("POST", "/v1/appScreenshotSets", {"data": {
            "type": "appScreenshotSets", "attributes": {"screenshotDisplayType": DISPLAY_TYPE},
            "relationships": {"appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": loc_id}}}}}))["data"]
    _, existing = asc.req("GET", f"/v1/appScreenshotSets/{shot_set['id']}/appScreenshots?limit=50")
    for shot in existing.get("data", []):
        asc.req("DELETE", f"/v1/appScreenshots/{shot['id']}")
    print(f"store screenshots ({DISPLAY_TYPE}), replaced {len(existing.get('data', []))}:")
    for path in sorted(glob.glob(os.path.join(HERE, "final", "en-US", "*.png"))):
        upload("appScreenshots", {}, {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": shot_set["id"]}}}, path)


def iap_review_screenshot():
    _, iaps = asc.req("GET", f"/v1/apps/{APP_ID}/inAppPurchasesV2")
    iap_id = iaps["data"][0]["id"]
    status, current = asc.req("GET", f"/v2/inAppPurchases/{iap_id}/appStoreReviewScreenshot")
    if status == 200 and current.get("data"):
        asc.req("DELETE", f"/v1/inAppPurchaseAppStoreReviewScreenshots/{current['data']['id']}")
    print("IAP review screenshot:")
    upload("inAppPurchaseAppStoreReviewScreenshots", {},
           {"inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": iap_id}}},
           os.path.join(HERE, "raw", "en-US", "07_Paywall.png"))


if __name__ == "__main__":
    store_screenshots()
    iap_review_screenshot()
