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
        let connection = app.buttons["home.connection"]
        XCTAssertTrue(connection.waitForExistence(timeout: 20), "home did not open without login")
        snap("01-home")

        connection.tap()
        let serverField = app.textFields["settings.server"]
        XCTAssertTrue(serverField.waitForExistence(timeout: 10), "server field missing")
        serverField.tap()
        serverField.typeText(serverURL)
        app.buttons["Use this server"].tap()
        sleep(2)
        snap("02-server-status")
        closeWindow()

        let assistantTile = app.buttons["module.assistant"]
        XCTAssertTrue(assistantTile.waitForExistence(timeout: 30), "home tiles missing")

        for module in ["assistant", "files", "projects", "studio", "security", "store", "settings"] {
            let tile = app.buttons["module.\(module)"]
            XCTAssertTrue(tile.waitForExistence(timeout: 10), "missing module \(module)")
            tile.tap()
            sleep(2)
            snap("03-\(module)")
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
        snap("04-settings-arabic")

        let english = app.buttons["English"]
        XCTAssertTrue(english.waitForExistence(timeout: 5))
        english.tap()
        sleep(1)
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 10), "English UI did not return")
    }
}
