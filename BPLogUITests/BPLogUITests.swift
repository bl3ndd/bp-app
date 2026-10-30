import XCTest

/// End-to-end flows on a clean in-memory store (`-UITEST`).
final class BPLogUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(_ arguments: [String]) {
        app = XCUIApplication()
        app.launchArguments = ["-UITEST"] + arguments
        app.launch()
    }

    /// Any element whose accessibility label contains `text` — reading numbers
    /// are combined into one element for VoiceOver ("128/82, mmHg, 70 bpm").
    @MainActor
    private func element(containing text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    @MainActor
    private func waitForFocus(_ field: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let focused = expectation(for: NSPredicate(format: "hasKeyboardFocus == true"), evaluatedWith: field)
        XCTAssertEqual(XCTWaiter.wait(for: [focused], timeout: 3), .completed, "focus moved to \(field)", file: file, line: line)
    }

    /// Types the way a user does: each number, then the form moves on by itself.
    @MainActor
    private func type(_ systolic: String, _ diastolic: String, pulse: String? = nil) {
        let field = app.textFields["Systolic"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        app.typeText(systolic)
        waitForFocus(app.textFields["Diastolic"])
        app.typeText(diastolic)
        if let pulse {
            waitForFocus(app.textFields["Pulse"])
            app.typeText(pulse)
        }
    }

    @MainActor
    private func addReading(_ systolic: String, _ diastolic: String, pulse: String? = nil) {
        app.buttons["Add Reading"].tap()
        type(systolic, diastolic, pulse: pulse)
        let save = app.buttons["Save Reading"]
        XCTAssertTrue(save.isEnabled, "reading is valid")
        save.tap()
        XCTAssertTrue(save.waitForNonExistence(timeout: 5), "entry sheet closed")
    }

    @MainActor
    private func tab(_ name: String) {
        app.tabBars.buttons[name].firstMatch.tap()
    }

    // MARK: Onboarding

    @MainActor
    func testOnboardingSkipsHealthAndRemindersThenOffersProAfterFirstReading() {
        launch(["-FREE"])
        XCTAssertTrue(app.staticTexts["Track your blood pressure"].waitForExistence(timeout: 5))
        XCTAssertTrue(element(containing: "not a medical device").exists)
        app.buttons["Get Started"].tap()
        XCTAssertTrue(app.staticTexts["Connect Apple Health"].waitForExistence(timeout: 5))
        app.buttons["Not Now"].tap()
        XCTAssertTrue(app.staticTexts["Daily reminders"].waitForExistence(timeout: 5))
        app.buttons["Skip"].tap()

        XCTAssertTrue(app.staticTexts["Track your blood pressure"].waitForExistence(timeout: 5), "empty Home, no paywall yet")
        XCTAssertFalse(app.staticTexts["Simply BP Pro"].exists)
        addReading("120", "78")
        XCTAssertTrue(app.staticTexts["Simply BP Pro"].waitForExistence(timeout: 5), "offered after the first reading")
        app.buttons["Not Now"].tap()
        addReading("118", "76")
        XCTAssertFalse(app.staticTexts["Simply BP Pro"].waitForExistence(timeout: 2), "only once")
    }

    // MARK: Entry

    @MainActor
    func testAddReadingShowsOnHome() {
        launch(["-SKIP_ONBOARDING", "-FREE"])
        addReading("128", "82", pulse: "70")
        XCTAssertTrue(element(containing: "128/82").waitForExistence(timeout: 3))
        XCTAssertTrue(element(containing: "70 bpm").exists)
        XCTAssertTrue(app.staticTexts["High · Stage 1"].exists)
    }

    @MainActor
    func testInvalidReadingExplainsTheCause() {
        launch(["-SKIP_ONBOARDING", "-FREE"])
        app.buttons["Add Reading"].tap()
        type("90", "20")  // "20" may still grow, so no error yet
        XCTAssertFalse(app.staticTexts["The bottom number should be between 30 and 160."].exists)
        app.textFields["Pulse"].tap()
        XCTAssertTrue(app.staticTexts["The bottom number should be between 30 and 160."].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Save Reading"].isEnabled)
    }

    @MainActor
    func testLowReadingShowsNote() {
        launch(["-SKIP_ONBOARDING", "-FREE"])
        app.buttons["Add Reading"].tap()
        type("85", "55")
        XCTAssertTrue(app.staticTexts["Low"].waitForExistence(timeout: 3))
        XCTAssertTrue(element(containing: "Below 90/60").exists)
    }

    @MainActor
    func testSeveralReadingsTodayShowTodaysAverage() {
        launch(["-SKIP_ONBOARDING", "-FREE"])
        addReading("120", "80")
        let todayCard = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Today'")).firstMatch
        XCTAssertFalse(todayCard.exists)
        addReading("130", "90")
        XCTAssertTrue(todayCard.waitForExistence(timeout: 3))
        XCTAssertTrue(todayCard.label.contains("125/85"))
    }

    // MARK: History

    @MainActor
    func testDeleteFromHistory() {
        launch(["-SKIP_ONBOARDING", "-FREE"])
        addReading("118", "76")
        tab("History")
        let row = app.cells.containing(NSPredicate(format: "label CONTAINS %@", "118/76")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.swipeLeft()
        app.buttons["Delete"].tap()
        XCTAssertTrue(app.staticTexts["No readings yet"].waitForExistence(timeout: 5))
    }

    // MARK: Pro gating

    @MainActor
    func testFreeUserHitsPaywallOnLongChartRange() {
        launch(["-SKIP_ONBOARDING", "-FREE"])
        addReading("125", "80")
        tab("Charts")
        app.buttons["90D"].tap()
        XCTAssertTrue(app.staticTexts["Simply BP Pro"].waitForExistence(timeout: 5))
        app.buttons["Not Now"].tap()
        XCTAssertTrue(app.buttons["30D"].isSelected, "range snaps back")
    }

    @MainActor
    func testFreeUserSeesLockedStats() {
        launch(["-SKIP_ONBOARDING", "-FREE"])
        addReading("125", "80")
        tab("Stats")
        XCTAssertTrue(app.staticTexts["Full statistics are part of Pro"].waitForExistence(timeout: 5))
        app.buttons["Unlock Pro"].tap()
        XCTAssertTrue(app.staticTexts["Simply BP Pro"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testProUserSeesStatsAndCanOpenReport() {
        launch(["-SKIP_ONBOARDING", "-SNAPSHOT"])
        addReading("125", "80")
        tab("Stats")
        XCTAssertTrue(app.staticTexts["Average"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Full statistics are part of Pro"].exists)
        app.buttons["Doctor Report"].tap()
        XCTAssertTrue(app.buttons["Create PDF Report"].waitForExistence(timeout: 5))
        app.buttons["Create PDF Report"].tap()
        XCTAssertFalse(app.staticTexts["Simply BP Pro"].waitForExistence(timeout: 2), "no paywall for Pro")
    }
}
