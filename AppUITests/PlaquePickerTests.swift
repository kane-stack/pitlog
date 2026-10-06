import XCTest

/// The year buttons of the sticker picker sit in a Form row next to the suggestion button. Each one
/// must fire only its own action (a row with plain buttons fires all of them on one tap).
final class PlaquePickerTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func openNewVehicleForm() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-UITestSampleData", "-legalNoticeAcknowledged", "YES"]
        app.launch()
        app.tabBars.buttons.element(boundBy: 1).tap()
        let add = app.buttons["addVehicleButton"]
        XCTAssertTrue(add.waitForExistence(timeout: 15))
        add.tap()
        XCTAssertTrue(app.textFields.firstMatch.waitForExistence(timeout: 10))
        return app
    }

    @MainActor
    private func scrollUntilVisible(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        for _ in 0..<10 {
            if element.exists && element.isHittable { return true }
            app.swipeUp()
        }
        return element.exists && element.isHittable
    }

    @MainActor
    private func chooseFromMenu(_ app: XCUIApplication, menu: String, option: String) {
        XCTAssertTrue(scrollUntilVisible(app.buttons[menu], in: app))
        app.buttons[menu].tap()
        let item = app.buttons[option]
        XCTAssertTrue(item.waitForExistence(timeout: 5))
        item.tap()
    }

    @MainActor
    private func shownYear(_ app: XCUIApplication) -> Int? {
        Int(app.staticTexts["plaqueYear"].label)
    }

    /// Taps next, previous, previous and checks every step moves the year by exactly one.
    @MainActor
    private func assertYearButtonsStepByOne(_ app: XCUIApplication, expectSuggestion: Bool) {
        let year = app.staticTexts["plaqueYear"]
        XCTAssertTrue(scrollUntilVisible(year, in: app))
        guard let start = shownYear(app) else { return XCTFail("year label is not a number") }

        let next = app.buttons["plaqueNextYear"]
        let previous = app.buttons["plaquePreviousYear"]
        let suggestion = app.buttons["plaqueUseSuggestion"]
        XCTAssertEqual(suggestion.exists, expectSuggestion)

        next.tap()
        XCTAssertEqual(shownYear(app), start + 1)
        previous.tap()
        XCTAssertEqual(shownYear(app), start)
        previous.tap()
        XCTAssertEqual(shownYear(app), start - 1)

        // Still no sticker entered: the suggestion row stays, nothing took it over.
        XCTAssertEqual(suggestion.exists, expectSuggestion)
    }

    @MainActor
    func testYearButtonsWithFirstRegistration() {
        let app = openNewVehicleForm()
        chooseFromMenu(app, menu: "First registration, month", option: "March")
        chooseFromMenu(app, menu: "First registration, year", option: "2020")
        assertYearButtonsStepByOne(app, expectSuggestion: true)
    }

    @MainActor
    func testYearButtonsWithoutFirstRegistration() {
        let app = openNewVehicleForm()
        assertYearButtonsStepByOne(app, expectSuggestion: false)
    }
}
