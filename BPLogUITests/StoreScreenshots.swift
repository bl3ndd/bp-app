import XCTest

/// Raw App Store screenshots from the demo data set. Skipped in normal test runs;
/// run with `TEST_RUNNER_STORE_SHOTS=1 xcodebuild test … -only-testing:BPLogUITests/StoreScreenshots`.
/// Shots are kept as named test attachments; appstore_screenshots/export.sh pulls them out.
final class StoreScreenshots: XCTestCase {
    private var app: XCUIApplication!
    private var savedAppearance: XCUIDevice.Appearance?

    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["STORE_SHOTS"] != nil, "set STORE_SHOTS to capture")
        continueAfterFailure = false
        // The store shows the light "paper" look whatever the phone is set to.
        // This flips the whole phone, so put the owner's setting back afterwards.
        savedAppearance = XCUIDevice.shared.appearance
        XCUIDevice.shared.appearance = .light
    }

    override func tearDownWithError() throws {
        if let savedAppearance { XCUIDevice.shared.appearance = savedAppearance }
    }

    @MainActor
    private func launch(_ arguments: [String]) {
        app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
    }

    @MainActor
    private func shot(_ name: String) {
        sleep(1)  // let animations settle
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func tab(_ name: String) {
        app.tabBars.buttons[name].firstMatch.tap()
    }

    @MainActor
    private func waitForFocus(_ field: XCUIElement) {
        let focused = expectation(for: NSPredicate(format: "hasKeyboardFocus == true"), evaluatedWith: field)
        _ = XCTWaiter.wait(for: [focused], timeout: 3)
    }

    @MainActor
    func testProScreens() {
        launch(["-DEMO", "-SNAPSHOT"])
        XCTAssertTrue(app.buttons["Add Reading"].waitForExistence(timeout: 10))
        shot("01_Home")

        app.buttons["Add Reading"].tap()
        let systolic = app.textFields["Systolic"]
        XCTAssertTrue(systolic.waitForExistence(timeout: 5))
        systolic.tap()
        app.typeText("128")
        waitForFocus(app.textFields["Diastolic"])
        app.typeText("82")
        waitForFocus(app.textFields["Pulse"])
        app.typeText("70")
        shot("02_AddReading")
        app.buttons["Cancel"].tap()

        tab("Charts")
        shot("03_Charts")

        tab("Stats")
        XCTAssertTrue(app.staticTexts["Average"].waitForExistence(timeout: 5))
        shot("04_Stats")
        app.swipeUp()
        shot("05_StatsMore")

        tab("Home")
        app.buttons["Doctor Report"].tap()
        app.buttons["Create PDF Report"].tap()
        sleep(2)
        shot("06_Report")
    }

    @MainActor
    func testPaywall() {
        launch(["-DEMO", "-FREE"])
        tab("Stats")
        app.buttons["Unlock Pro"].tap()
        XCTAssertTrue(app.staticTexts["Simply BP Pro"].waitForExistence(timeout: 5))
        shot("07_Paywall")
    }
}
