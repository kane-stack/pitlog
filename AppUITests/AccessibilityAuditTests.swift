import XCTest

final class AccessibilityAuditTests: XCTestCase {
    /// Issue descriptions of the running audit (the issue handler is escaping, so this is a property).
    private var auditReport: [String] = []

    override func setUp() {
        continueAfterFailure = false
        auditReport = []
    }

    // MARK: Launch

    /// Sample data, notice already acknowledged unless asked otherwise.
    @MainActor
    private func launch(german: Bool = false, largeText: Bool = false, acknowledged: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-UITestSampleData"]
        if acknowledged { app.launchArguments += ["-legalNoticeAcknowledged", "YES"] }
        if german { app.launchArguments += ["-AppleLanguages", "(de)", "-AppleLocale", "de_AT"] }
        if largeText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launch()
        return app
    }

    // MARK: Helpers

    /// Runs the audit, attaches every issue as text and never filters anything by itself.
    @MainActor
    private func audit(_ app: XCUIApplication, _ name: String) throws {
        defer {
            if !auditReport.isEmpty {
                let attachment = XCTAttachment(string: auditReport.joined(separator: "\n\n"))
                attachment.name = "audit-\(name).txt"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
        // The audit sometimes runs into its own time limit on slow CI machines (code -56). That is
        // an infrastructure error, not a finding, so it is retried once. Findings are never retried.
        for attempt in 1...2 {
            do {
                try runAudit(app, name)
                break
            } catch let error as NSError
                where error.domain == "com.apple.xcode.xctest.accessibilityAudit" && error.code == -56 && attempt == 1 {
                auditReport.append("(audit timed out, retrying)")
                continue
            }
        }
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "audit-\(name).png"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    /// Labels of the buttons inside the navigation bars, collected before the audit starts.
    private var navigationBarButtonLabels: Set<String> = []

    /// Structural check: the issue's button has the label of a button inside a navigation bar.
    private func isNavigationBarButton(_ element: XCUIElement) -> Bool {
        navigationBarButtonLabels.contains(element.label)
    }

    @MainActor
    private func runAudit(_ app: XCUIApplication, _ name: String) throws {
        navigationBarButtonLabels = Set(
            app.navigationBars.buttons.allElementsBoundByIndex.map(\.label).filter { !$0.isEmpty })
        try app.performAccessibilityAudit { issue in
            let element = issue.element.map {
                "type=\($0.elementType.rawValue) label='\($0.label)' id='\($0.identifier)' frame=\($0.frame)"
            } ?? "no element"
            // Printed so the CI log shows it even without access to the .xcresult.
            print("AUDIT[\(name)] \(issue.auditType) | \(issue.compactDescription) | \(element)")
            self.auditReport.append(
                "[\(issue.auditType)] \(issue.compactDescription)\n\(issue.detailedDescription)\nelement: \(element)")
            // The only filter: UIKit bar button items of the system navigation bar ("Save", "Cancel")
            // do not follow Dynamic Type and are not ours to change. Nothing else is ignored,
            // and no whole audit category is switched off.
            if issue.auditType == .dynamicType,
               let target = issue.element,
               target.elementType == .button,
               self.isNavigationBarButton(target) {
                self.auditReport.append("(ignored: system navigation bar button)")
                return true
            }
            return false
        }
    }

    @MainActor
    private func shot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "\(name).png"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func tap(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        guard element.waitForExistence(timeout: timeout) else { return false }
        element.tap()
        return true
    }

    // MARK: Screenshot tours (no assertions, for looking at the layout)

    @MainActor
    private func tour(german: Bool, largeText: Bool) {
        let prefix = "\(german ? "de" : "en")-\(largeText ? "xxxl" : "default")"
        let app = launch(german: german, largeText: largeText, acknowledged: false)
        shot(app, "\(prefix)-01-notice")
        _ = tap(app.buttons["acknowledgeButton"])

        shot(app, "\(prefix)-02-upcoming")

        app.tabBars.buttons.element(boundBy: 1).tap()
        shot(app, "\(prefix)-03-vehicles")

        if tap(app.buttons["addVehicleButton"]) {
            shot(app, "\(prefix)-04-form-top")
            for index in 1...3 {
                app.swipeUp()
                shot(app, "\(prefix)-04-form-\(index)")
            }
            _ = tap(app.buttons["cancelButton"])
        }

        if tap(app.cells.firstMatch) {
            shot(app, "\(prefix)-05-detail")
            app.swipeUp()
            shot(app, "\(prefix)-05-detail-bottom")
            let record = app.buttons["recordInspectionButton"]
            if !record.exists { app.swipeUp() }
            if tap(record) {
                shot(app, "\(prefix)-06-record-date")
                if tap(app.buttons["continueButton"]) {
                    shot(app, "\(prefix)-06-record-confirm")
                }
                _ = tap(app.buttons["cancelButton"])
            }
            app.navigationBars.buttons.firstMatch.tap()
        }

        app.tabBars.buttons.element(boundBy: 2).tap()
        shot(app, "\(prefix)-07-settings")
        for index in 0..<3 where app.cells.count > index {
            app.cells.element(boundBy: index).tap()
            shot(app, "\(prefix)-08-settings-\(index)")
            app.navigationBars.buttons.firstMatch.tap()
        }
    }

    @MainActor func testTourEnglishDefault() { tour(german: false, largeText: false) }
    @MainActor func testTourGermanDefault() { tour(german: true, largeText: false) }
    @MainActor func testTourEnglishLargeText() { tour(german: false, largeText: true) }
    @MainActor func testTourGermanLargeText() { tour(german: true, largeText: true) }

    // MARK: Audits

    @MainActor
    func testFirstLaunchNoticePassesAccessibilityAudit() throws {
        try audit(launch(acknowledged: false), "notice-en")
    }

    @MainActor
    func testFirstLaunchNoticePassesAccessibilityAuditInGerman() throws {
        try audit(launch(german: true, acknowledged: false), "notice-de")
    }

    @MainActor
    func testUpcomingTabPassesAccessibilityAudit() throws {
        try audit(launch(), "upcoming-en")
    }

    @MainActor
    func testVehicleListPassesAccessibilityAudit() throws {
        let app = launch()
        app.tabBars.buttons.element(boundBy: 1).tap()
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 5))
        try audit(app, "vehicles-en")
    }

    @MainActor
    func testAddVehicleFormPassesAccessibilityAudit() throws {
        let app = launch()
        app.tabBars.buttons.element(boundBy: 1).tap()
        XCTAssertTrue(tap(app.buttons["addVehicleButton"]))
        let nameField = app.textFields.firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        // A valid form: a disabled "Save" is exempt from contrast rules, an enabled one must pass.
        nameField.tap()
        nameField.typeText("Test")
        try audit(app, "form-en")
    }

    /// Same form, scrolled down to the inspection sticker picker: tells apart findings of the top and the bottom half.
    @MainActor
    func testAddVehicleFormScrolledPassesAccessibilityAudit() throws {
        let app = launch()
        app.tabBars.buttons.element(boundBy: 1).tap()
        XCTAssertTrue(tap(app.buttons["addVehicleButton"]))
        let nameField = app.textFields.firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("Test")
        app.swipeUp()
        app.swipeUp()
        try audit(app, "form-scrolled-en")
    }

    @MainActor
    func testVehicleDetailWithPickerlCardPassesAccessibilityAudit() throws {
        let app = launch()
        app.tabBars.buttons.element(boundBy: 1).tap()
        XCTAssertTrue(tap(app.cells.firstMatch))
        XCTAssertTrue(app.buttons["recordInspectionButton"].waitForExistence(timeout: 5))
        try audit(app, "detail-en")
    }

    @MainActor
    func testVehicleDetailPassesAccessibilityAuditInGerman() throws {
        let app = launch(german: true)
        app.tabBars.buttons.element(boundBy: 1).tap()
        XCTAssertTrue(tap(app.cells.firstMatch))
        XCTAssertTrue(app.buttons["recordInspectionButton"].waitForExistence(timeout: 5))
        try audit(app, "detail-de")
    }

    @MainActor
    func testSettingsAndLegalPassAccessibilityAudit() throws {
        let app = launch()
        app.tabBars.buttons.element(boundBy: 2).tap()
        XCTAssertTrue(tap(app.cells.firstMatch))
        try audit(app, "legal-en")
    }
}
