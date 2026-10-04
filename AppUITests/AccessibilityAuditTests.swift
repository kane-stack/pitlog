import XCTest

final class AccessibilityAuditTests: XCTestCase {
    @MainActor
    func testLaunchScreenPassesAccessibilityAudit() throws {
        let app = XCUIApplication()
        app.launch()
        try app.performAccessibilityAudit()
    }

    @MainActor
    func testLaunchScreenPassesAccessibilityAuditInGerman() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(de)", "-AppleLocale", "de_AT"]
        app.launch()
        try app.performAccessibilityAudit()
    }
}
