import XCTest

final class NoterUITests: XCTestCase {
    @MainActor
    func testCreateClassAndNavigateToLearn() throws {
        let app = XCUIApplication()
        app.launch()

        let nameField = app.textFields["Full name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.tap()
        nameField.typeText("Preview Tester")

        let emailField = app.textFields["Email"]
        emailField.tap()
        emailField.typeText("tester@example.com")

        let createButton = app.buttons["Create account"]
        createButton.tap()

        let newClassButton = app.buttons["New Class"]
        XCTAssertTrue(newClassButton.waitForExistence(timeout: 3))
        newClassButton.tap()

        let titleField = app.textFields["Title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 2))
        titleField.tap()
        titleField.typeText("UI Test Course")

        let saveButton = app.buttons["Save"]
        saveButton.tap()

        let learnTab = app.tabBars.buttons["Learn"]
        XCTAssertTrue(learnTab.waitForExistence(timeout: 2))
        learnTab.tap()

        XCTAssertTrue(app.navigationBars["Learn"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.segmentedControls.buttons["Flashcards"].exists)
        XCTAssertTrue(app.buttons["Regenerate"].exists)
    }
}
