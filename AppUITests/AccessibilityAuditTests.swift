import XCTest

final class AccessibilityAuditTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Sample data, notice already acknowledged.
    @MainActor
    private func launch(german: Bool = false, acknowledged: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-UITestSampleData"]
        if acknowledged { app.launchArguments += ["-legalNoticeAcknowledged", "YES"] }
        if german { app.launchArguments += ["-AppleLanguages", "(de)", "-AppleLocale", "de_AT"] }
        app.launch()
        return app
    }

    @MainActor
    func testFirstLaunchNoticePassesAccessibilityAudit() throws {
        let app = launch(acknowledged: false)
        try app.performAccessibilityAudit()
    }

    @MainActor
    func testFirstLaunchNoticePassesAccessibilityAuditInGerman() throws {
        let app = launch(german: true, acknowledged: false)
        try app.performAccessibilityAudit()
    }

    @MainActor
    func testUpcomingTabPassesAccessibilityAudit() throws {
        let app = launch()
        try app.performAccessibilityAudit()
    }

    @MainActor
    func testVehicleListPassesAccessibilityAudit() throws {
        let app = launch()
        app.tabBars.buttons.element(boundBy: 1).tap()
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 5))
        try app.performAccessibilityAudit()
    }

    @MainActor
    func testAddVehicleFormPassesAccessibilityAudit() throws {
        let app = launch()
        app.tabBars.buttons.element(boundBy: 1).tap()
        app.navigationBars.firstMatch.buttons.firstMatch.tap()
        XCTAssertTrue(app.textFields.firstMatch.waitForExistence(timeout: 5))
        try app.performAccessibilityAudit()
    }

    @MainActor
    func testVehicleDetailWithPickerlCardPassesAccessibilityAudit() throws {
        let app = launch()
        app.tabBars.buttons.element(boundBy: 1).tap()
        let cell = app.cells.firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 5))
        cell.tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'inspection' OR label CONTAINS[c] 'Begutachtung'")).firstMatch.waitForExistence(timeout: 5))
        try app.performAccessibilityAudit()
    }

    @MainActor
    func testVehicleDetailPassesAccessibilityAuditInGerman() throws {
        let app = launch(german: true)
        app.tabBars.buttons.element(boundBy: 1).tap()
        let cell = app.cells.firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 5))
        cell.tap()
        try app.performAccessibilityAudit()
    }

    @MainActor
    func testSettingsAndLegalPassAccessibilityAudit() throws {
        let app = launch()
        app.tabBars.buttons.element(boundBy: 2).tap()
        app.cells.firstMatch.tap()
        try app.performAccessibilityAudit()
    }
}
