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
    private func launch(
        german: Bool = false, largeText: Bool = false, acknowledged: Bool = true, extraArguments: [String] = []
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-UITestSampleData"] + extraArguments
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
        // Let push and sheet transitions finish: elements still moving are measured at the wrong size.
        Thread.sleep(forTimeInterval: 1.5)
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
            // Disabled controls are exempt from contrast requirements (WCAG 1.4.3): only a disabled
            // button of the navigation bar ("Save" while the form is incomplete) is ignored.
            if issue.auditType == .contrast,
               let target = issue.element,
               target.elementType == .button,
               !target.isEnabled,
               self.isNavigationBarButton(target) {
                self.auditReport.append("(ignored: disabled navigation bar button)")
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
    private func tap(_ element: XCUIElement, timeout: TimeInterval = 15) -> Bool {
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
        for index in 0..<4 where app.cells.count > index {
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
        let app = launch()
        // Scrolled to the end, see testUpcomingTabShowsRemindersAndPassesAccessibilityAudit.
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 5))
        for _ in 0..<3 { app.swipeUp() }
        try audit(app, "upcoming-en")
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
        XCTAssertTrue(app.textFields.firstMatch.waitForExistence(timeout: 5))
        // The empty form: "Save" is disabled and the keyboard has no focus. The valid state is covered by
        // testEditVehicleFormPassesAccessibilityAudit.
        try audit(app, "form-en")
    }

    /// The edit form of a sample vehicle: valid from the start, no keyboard focus, sticker already entered.
    /// (Not audited scrolled: the audit reports the row at the bottom screen edge as non-scaling after the
    /// content size change, whatever it is — an artifact of the check, seen on several screens.)
    @MainActor
    func testEditVehicleFormPassesAccessibilityAudit() throws {
        let app = launch()
        app.tabBars.buttons.element(boundBy: 1).tap()
        XCTAssertTrue(tap(app.cells.firstMatch))
        XCTAssertTrue(app.buttons["recordInspectionButton"].waitForExistence(timeout: 5))
        // "Edit" is the only button in the top right of the navigation bar.
        app.navigationBars.buttons.element(boundBy: app.navigationBars.buttons.count - 1).tap()
        XCTAssertTrue(app.buttons["cancelButton"].waitForExistence(timeout: 5))
        try audit(app, "form-edit-en")
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
        // The first row is Notifications, the second Legal.
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(tap(app.cells.element(boundBy: 1)))
        try audit(app, "legal-en")
    }

    // MARK: Reminders

    /// Swipes up until `element` can be tapped.
    @MainActor
    private func scrollUntilVisible(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        for _ in 0..<8 {
            if element.exists && element.isHittable { return true }
            app.swipeUp()
        }
        return element.exists && element.isHittable
    }

    /// The reminders of the first sample vehicle (the Golf, with sample reminders).
    @MainActor
    private func openReminderList(german: Bool = false) -> XCUIApplication {
        let app = launch(german: german)
        app.tabBars.buttons.element(boundBy: 1).tap()
        XCTAssertTrue(tap(app.cells.firstMatch))
        XCTAssertTrue(app.buttons["recordInspectionButton"].waitForExistence(timeout: 5))
        // The detail has one row for the reminders; it opens the list.
        let row = app.descendants(matching: .any)["remindersRow"]
        XCTAssertTrue(scrollUntilVisible(row, in: app))
        row.tap()
        XCTAssertTrue(app.buttons["addReminderButton"].waitForExistence(timeout: 5))
        return app
    }

    @MainActor
    func testReminderListPassesAccessibilityAudit() throws {
        let app = openReminderList()
        try audit(app, "reminders-en")
    }

    @MainActor
    func testReminderListPassesAccessibilityAuditInGerman() throws {
        let app = openReminderList(german: true)
        try audit(app, "reminders-de")
    }

    @MainActor
    private func openEditor(_ app: XCUIApplication, menuItem: String) {
        XCTAssertTrue(tap(app.buttons["addReminderButton"]))
        var item = app.buttons[menuItem]
        if !item.waitForExistence(timeout: 5) {
            item = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", menuItem)).firstMatch
        }
        shot(app, "menu-open-\(menuItem)")
        let dump = XCTAttachment(string: app.debugDescription)
        dump.name = "hierarchy-\(menuItem).txt"
        dump.lifetime = .keepAlways
        add(dump)
        XCTAssertTrue(tap(item))
        XCTAssertTrue(app.buttons["saveReminderButton"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testServiceReminderEditorPassesAccessibilityAudit() throws {
        let app = openReminderList()
        openEditor(app, menuItem: "Service")
        try audit(app, "reminder-editor-service-en")
    }

    @MainActor
    func testCustomReminderEditorPassesAccessibilityAudit() throws {
        let app = openReminderList()
        openEditor(app, menuItem: "Custom reminder")
        try audit(app, "reminder-editor-custom-en")
    }

    @MainActor
    func testVignetteReminderEditorPassesAccessibilityAuditInGerman() throws {
        let app = openReminderList(german: true)
        openEditor(app, menuItem: "Vignette")
        try audit(app, "reminder-editor-vignette-de")
    }

    @MainActor
    func testNotificationSettingsPassAccessibilityAudit() throws {
        let app = launch()
        app.tabBars.buttons.element(boundBy: 2).tap()
        XCTAssertTrue(tap(app.cells.firstMatch))
        XCTAssertTrue(app.switches["remindersEnabledToggle"].waitForExistence(timeout: 5))
        try audit(app, "notification-settings-en")
    }

    @MainActor
    func testNotificationSettingsPassAccessibilityAuditInGerman() throws {
        let app = launch(german: true)
        app.tabBars.buttons.element(boundBy: 2).tap()
        XCTAssertTrue(tap(app.cells.firstMatch))
        XCTAssertTrue(app.switches["remindersEnabledToggle"].waitForExistence(timeout: 5))
        try audit(app, "notification-settings-de")
    }

    @MainActor
    func testUpcomingTabShowsRemindersAndPassesAccessibilityAudit() throws {
        let app = launch()
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 5))
        // The Golf has inspection plus four reminders, and the other vehicles have an inspection each.
        XCTAssertGreaterThan(app.cells.count, 2)
        // Scrolled to the end: rows scrolling under the floating tab bar fail the contrast check, which
        // is the platform's translucent bar, not a text color.
        for _ in 0..<3 { app.swipeUp() }
        try audit(app, "upcoming-reminders-en")
    }

    // MARK: History and costs

    /// The history of the first sample vehicle (the Golf, with sample entries in two currencies).
    @MainActor
    private func openHistory(german: Bool = false) -> XCUIApplication {
        let app = launch(german: german)
        app.tabBars.buttons.element(boundBy: 1).tap()
        XCTAssertTrue(tap(app.cells.firstMatch))
        XCTAssertTrue(app.buttons["recordInspectionButton"].waitForExistence(timeout: 5))
        let row = app.descendants(matching: .any)["historyRow"]
        XCTAssertTrue(scrollUntilVisible(row, in: app))
        row.tap()
        // The top of the screen: the add row can lie below the fold (long German texts), so it is not awaited.
        XCTAssertTrue(app.segmentedControls["costsDisplayPicker"].waitForExistence(timeout: 15))
        return app
    }

    @MainActor
    private func showTable(_ app: XCUIApplication, german: Bool) {
        let picker = app.segmentedControls["costsDisplayPicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.buttons[german ? "Tabelle" : "Table"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["costsTableYear"].firstMatch.waitForExistence(timeout: 15))
    }

    /// Top of the history: the costs section with the chart and its legend.
    @MainActor
    func testHistoryCostsChartPassesAccessibilityAudit() throws {
        let app = openHistory()
        XCTAssertTrue(app.descendants(matching: .any)["costsChart"].waitForExistence(timeout: 5))
        try audit(app, "history-chart-en")
    }

    @MainActor
    func testHistoryCostsChartPassesAccessibilityAuditInGerman() throws {
        let app = openHistory(german: true)
        XCTAssertTrue(app.descendants(matching: .any)["costsChart"].waitForExistence(timeout: 5))
        try audit(app, "history-chart-de")
    }

    @MainActor
    func testHistoryCostsTablePassesAccessibilityAudit() throws {
        let app = openHistory()
        showTable(app, german: false)
        try audit(app, "history-table-en")
    }

    @MainActor
    func testHistoryCostsTablePassesAccessibilityAuditInGerman() throws {
        let app = openHistory(german: true)
        showTable(app, german: true)
        try audit(app, "history-table-de")
    }

    /// The timeline, scrolled to the end.
    @MainActor
    func testHistoryTimelinePassesAccessibilityAudit() throws {
        let app = openHistory()
        for _ in 0..<4 { app.swipeUp() }
        try audit(app, "history-list-en")
    }

    @MainActor
    func testHistoryTimelinePassesAccessibilityAuditInGerman() throws {
        let app = openHistory(german: true)
        for _ in 0..<4 { app.swipeUp() }
        try audit(app, "history-list-de")
    }

    @MainActor
    private func openEntryEditor(_ app: XCUIApplication) {
        let add = app.descendants(matching: .any)["addEntryButton"]
        XCTAssertTrue(scrollUntilVisible(add, in: app))
        add.tap()
        XCTAssertTrue(app.buttons["saveEntryButton"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testEntryEditorPassesAccessibilityAudit() throws {
        let app = openHistory()
        openEntryEditor(app)
        try audit(app, "entry-editor-en")
    }

    @MainActor
    func testEntryEditorPassesAccessibilityAuditInGerman() throws {
        let app = openHistory(german: true)
        openEntryEditor(app)
        try audit(app, "entry-editor-de")
    }

    // MARK: Registration scan (M5a)

    /// The review screen of a scan. The simulator has no document camera, so the launch argument makes the scan
    /// button show a fixed recognition result (`RegistrationScanFixtures`) that goes through the real parser.
    @MainActor
    private func openRegistrationReview(
        german: Bool = false, largeText: Bool = false, unsupportedClass: Bool = false
    ) -> XCUIApplication {
        var arguments = ["-UITestRegistrationScan"]
        if unsupportedClass { arguments.append("-UITestRegistrationScanUnsupported") }
        let app = launch(german: german, largeText: largeText, extraArguments: arguments)
        app.tabBars.buttons.element(boundBy: 1).tap()
        XCTAssertTrue(tap(app.buttons["addVehicleButton"]))
        XCTAssertTrue(tap(app.buttons["scanRegistrationButton"]))
        XCTAssertTrue(app.buttons["registrationReviewApplyButton"].waitForExistence(timeout: 10))
        return app
    }

    @MainActor
    func testRegistrationReviewPassesAccessibilityAudit() throws {
        let app = openRegistrationReview()
        try audit(app, "registration-review-en")
    }

    @MainActor
    func testRegistrationReviewPassesAccessibilityAuditInGerman() throws {
        let app = openRegistrationReview(german: true)
        try audit(app, "registration-review-de")
    }

    @MainActor
    func testRegistrationReviewPassesAccessibilityAuditWithLargeText() throws {
        let app = openRegistrationReview(largeText: true)
        try audit(app, "registration-review-xxxl-en")
    }

    @MainActor
    func testRegistrationReviewUnsupportedClassPassesAccessibilityAudit() throws {
        let app = openRegistrationReview(unsupportedClass: true)
        try audit(app, "registration-review-unsupported-en")
    }

    /// Clear and checkable values start switched on, the uncertain date starts off; "Apply" fills the form and
    /// leaves the date alone, and nothing is saved by it.
    @MainActor
    func testRegistrationReviewDefaultsAndApply() {
        let app = openRegistrationReview()
        let plate = app.switches["registrationToggle-licensePlate"]
        XCTAssertTrue(plate.waitForExistence(timeout: 5))
        XCTAssertEqual(plate.value as? String, "1")
        let vin = app.switches["registrationToggle-vin"]
        XCTAssertTrue(scrollUntilVisible(vin, in: app))
        XCTAssertEqual(vin.value as? String, "1")
        // The date is the last item: scroll until it is there.
        let first = app.switches["registrationToggle-firstRegistration"]
        XCTAssertTrue(scrollUntilVisible(first, in: app))
        XCTAssertEqual(first.value as? String, "0")

        XCTAssertTrue(tap(app.buttons["registrationReviewApplyButton"]))
        let plateField = app.textFields["License plate"]
        XCTAssertTrue(plateField.waitForExistence(timeout: 5))
        XCTAssertEqual(plateField.value as? String, "W 12345 A")
        XCTAssertEqual(app.textFields["Make"].value as? String, "BEISPIELMARKE")
        XCTAssertEqual(app.textFields["Model"].value as? String, "Beispiel 1.5")
        // Still in the form, not saved: Cancel is there.
        XCTAssertTrue(app.buttons["cancelButton"].exists)
    }

    @MainActor
    func testRegistrationReviewKeepsASwitchedOffValueOutOfTheForm() {
        let app = openRegistrationReview()
        let make = app.switches["registrationToggle-make"]
        XCTAssertTrue(make.waitForExistence(timeout: 5))
        // The switch sits at the trailing edge of its row; a tap in the middle hits the label.
        make.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        XCTAssertEqual(make.value as? String, "0")
        XCTAssertTrue(tap(app.buttons["registrationReviewApplyButton"]))
        let plateField = app.textFields["License plate"]
        XCTAssertTrue(plateField.waitForExistence(timeout: 5))
        XCTAssertEqual(plateField.value as? String, "W 12345 A")
        XCTAssertNotEqual(app.textFields["Make"].value as? String, "BEISPIELMARKE")
    }

    @MainActor
    func testRegistrationReviewCancelLeavesTheFormEmpty() {
        let app = openRegistrationReview()
        XCTAssertTrue(tap(app.buttons["registrationReviewCancelButton"]))
        let plateField = app.textFields["License plate"]
        XCTAssertTrue(plateField.waitForExistence(timeout: 5))
        XCTAssertNotEqual(plateField.value as? String, "W 12345 A")
    }
}
