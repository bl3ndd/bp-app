"""Fill Simply BP's App Store Connect metadata from ASO.md (en-US).

Reuses Mezame's minimal API client and key config (the key never lives in this
repo): run with Mezame's venv, which has pyjwt + cryptography.

    ~/Documents/projects/kpt-diary/venv/bin/python scripts/asc_fill.py

Sets: subtitle, privacy policy URL, categories, version description / keywords /
promo text / support + marketing URLs, copyright, age rating, review details.
App Privacy answers and screenshots are not available through the API.
"""
import os
import re
import sys

sys.path.insert(0, os.path.expanduser("~/Documents/projects/kpt-diary/scripts/asc_l10n"))
import asc  # noqa: E402

APP_ID = "6828866713"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASO = open(os.path.join(ROOT, "ASO.md")).read()

SUBTITLE = "Tracker, Charts & Doctor PDF"
KEYWORDS = re.search(r"\*\*Keywords \([^)]*\)[^\n]*\n\s*`([^`]+)`", ASO).group(1)
SITE = "https://bp-app-site.vercel.app"
COPYRIGHT = "2026 Evgenii Varzin"
REVIEW_EMAIL = "woodoo2013@gmail.com"


def section(title):
    """Body of a `## title` section in ASO.md."""
    m = re.search(rf"^## {re.escape(title)}[^\n]*\n(.*?)(?=^## |\Z)", ASO, re.S | re.M)
    return m.group(1).strip()


def check(label, status, payload):
    ok = 200 <= status < 300
    print(f"{'ok ' if ok else 'ERR'} {label} ({status}) {asc.errmsg(payload)}")
    return ok


def main():
    # App info: subtitle + privacy URL, categories.
    _, infos = asc.req("GET", f"/v1/apps/{APP_ID}/appInfos")
    info_id = infos["data"][0]["id"]
    _, locs = asc.req("GET", f"/v1/appInfos/{info_id}/appInfoLocalizations")
    info_loc = next(l for l in locs["data"] if l["attributes"]["locale"] == "en-US")
    check("subtitle + privacy URL", *asc.req("PATCH", f"/v1/appInfoLocalizations/{info_loc['id']}", {"data": {
        "type": "appInfoLocalizations", "id": info_loc["id"],
        "attributes": {"subtitle": SUBTITLE, "privacyPolicyUrl": f"{SITE}/privacy.html"}}}))
    check("categories", *asc.req("PATCH", f"/v1/appInfos/{info_id}", {"data": {
        "type": "appInfos", "id": info_id, "relationships": {
            "primaryCategory": {"data": {"type": "appCategories", "id": "HEALTH_AND_FITNESS"}},
            "secondaryCategory": {"data": {"type": "appCategories", "id": "MEDICAL"}}}}}))

    # Age rating: health information, nothing else.
    _, age = asc.req("GET", f"/v1/appInfos/{info_id}/ageRatingDeclaration")
    none = "NONE"
    check("age rating", *asc.req("PATCH", f"/v1/ageRatingDeclarations/{age['data']['id']}", {"data": {
        "type": "ageRatingDeclarations", "id": age["data"]["id"], "attributes": {
            "medicalOrTreatmentInformation": "INFREQUENT_OR_MILD",
            "healthOrWellnessTopics": True,
            "alcoholTobaccoOrDrugUseOrReferences": none, "contests": none, "gamblingSimulated": none,
            "gunsOrOtherWeapons": none, "horrorOrFearThemes": none, "matureOrSuggestiveThemes": none,
            "profanityOrCrudeHumor": none, "sexualContentGraphicAndNudity": none, "sexualContentOrNudity": none,
            "violenceCartoonOrFantasy": none, "violenceRealistic": none,
            "violenceRealisticProlongedGraphicOrSadistic": none,
            "gambling": False, "lootBox": False, "unrestrictedWebAccess": False, "messagingAndChat": False,
            "userGeneratedContent": False, "advertising": False, "parentalControls": False,
            "ageAssurance": False, "socialMedia": False}}}))

    # Version 1.0: copyright, localization texts, review details.
    _, versions = asc.req("GET", f"/v1/apps/{APP_ID}/appStoreVersions?filter[appStoreState]=PREPARE_FOR_SUBMISSION")
    version_id = versions["data"][0]["id"]
    check("copyright", *asc.req("PATCH", f"/v1/appStoreVersions/{version_id}", {"data": {
        "type": "appStoreVersions", "id": version_id, "attributes": {"copyright": COPYRIGHT}}}))
    _, vlocs = asc.req("GET", f"/v1/appStoreVersions/{version_id}/appStoreVersionLocalizations")
    vloc = next(l for l in vlocs["data"] if l["attributes"]["locale"] == "en-US")
    check("description, keywords, promo, URLs", *asc.req("PATCH", f"/v1/appStoreVersionLocalizations/{vloc['id']}", {"data": {
        "type": "appStoreVersionLocalizations", "id": vloc["id"], "attributes": {
            "description": section("Description"),
            "keywords": KEYWORDS,
            "promotionalText": section("Promotional text (170)"),
            "supportUrl": f"{SITE}/support.html",
            "marketingUrl": f"{SITE}/"}}}))

    # Review contact: reuse Mezame's name and phone, this app's support email.
    _, mez = asc.req("GET", "/v1/apps/6783373052/appStoreVersions?limit=1")
    _, mez_review = asc.req("GET", f"/v1/appStoreVersions/{mez['data'][0]['id']}/appStoreReviewDetail")
    contact = mez_review["data"]["attributes"]
    review = {"contactFirstName": contact["contactFirstName"], "contactLastName": contact["contactLastName"],
              "contactPhone": contact["contactPhone"], "contactEmail": REVIEW_EMAIL,
              "demoAccountRequired": False, "notes": section("Notes for Review (2.3.1(a))")}
    status, existing = asc.req("GET", f"/v1/appStoreVersions/{version_id}/appStoreReviewDetail")
    if status == 200 and existing.get("data"):
        check("review details", *asc.req("PATCH", f"/v1/appStoreReviewDetails/{existing['data']['id']}", {"data": {
            "type": "appStoreReviewDetails", "id": existing["data"]["id"], "attributes": review}}))
    else:
        check("review details", *asc.req("POST", "/v1/appStoreReviewDetails", {"data": {
            "type": "appStoreReviewDetails", "attributes": review,
            "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}}}}}))


if __name__ == "__main__":
    main()
