import XCTest

final class ScreenshotTests: XCTestCase {
    private var app: XCUIApplication!

    private var serverURL: String {
        ProcessInfo.processInfo.environment["NEXUS_TEST_SERVER"] ?? "http://127.0.0.1:8000"
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    private func snap(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func closeWindow() {
        let close = app.buttons["Close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5), "window close button missing")
        close.tap()
    }

    func testFullAppFlowWithScreenshots() throws {
        let serverField = app.textFields["auth.server"]
        XCTAssertTrue(serverField.waitForExistence(timeout: 20), "auth screen did not appear")
        snap("01-auth")

        serverField.tap()
        serverField.typeText(serverURL)
        let save = app.buttons["Use this server"]
        XCTAssertTrue(save.exists)
        save.tap()

        let registerSegment = app.segmentedControls.buttons["Create account"]
        XCTAssertTrue(registerSegment.waitForExistence(timeout: 10))
        registerSegment.tap()

        let name = app.textFields["auth.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 10), "name field missing")
        name.tap()
        name.typeText("Screenshot Runner")

        let email = app.textFields["auth.email"]
        email.tap()
        email.typeText("shot-\(UUID().uuidString.prefix(8))@example.com")

        let password = app.secureTextFields["auth.password"]
        password.tap()
        password.typeText("NexusTest!2026")

        app.buttons["auth.submit"].tap()

        let assistantTile = app.buttons["module.assistant"]
        XCTAssertTrue(assistantTile.waitForExistence(timeout: 30), "home did not appear after registration")
        sleep(2)
        snap("02-home")

        app.buttons["home.connection"].tap()
        sleep(1)
        snap("03-server-status")
        closeWindow()

        for module in ["assistant", "files", "projects", "studio", "security", "store", "settings"] {
            let tile = app.buttons["module.\(module)"]
            XCTAssertTrue(tile.waitForExistence(timeout: 10), "missing module \(module)")
            tile.tap()
            sleep(2)
            snap("04-\(module)")
            closeWindow()
            XCTAssertTrue(app.buttons["module.assistant"].waitForExistence(timeout: 10), "did not return home")
        }

        app.buttons["dock.settings"].tap()
        sleep(1)
        let arabic = app.buttons["العربية"]
        XCTAssertTrue(arabic.waitForExistence(timeout: 10), "language button missing")
        arabic.tap()
        sleep(2)
        XCTAssertTrue(app.staticTexts["الإعدادات"].waitForExistence(timeout: 10), "Arabic UI did not apply")
        snap("05-settings-arabic")

        let english = app.buttons["English"]
        XCTAssertTrue(english.waitForExistence(timeout: 5))
        english.tap()
        sleep(1)
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 10), "English UI did not return")
    }
}
