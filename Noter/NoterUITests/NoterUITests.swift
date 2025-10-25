//
//  NoterUITests.swift
//  NoterUITests
//
//  Created by Daniel Grant on 10/25/25.
//

import XCTest

final class NoterUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAddClassAndNavigateToLearn() {
        let app = XCUIApplication()
        app.launch()

        let nameField = app.textFields["Name"]
        if nameField.exists {
            nameField.tap()
            nameField.typeText("Test User")

            let emailField = app.textFields["Email"]
            emailField.tap()
            emailField.typeText("tester@example.com")

            app.buttons["Continue"].tap()
        }

        app.navigationBars.buttons["Add Class"].tap()

        let titleField = app.textFields["Title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 2))
        titleField.tap()
        titleField.typeText("UI Test Class")

        let courseField = app.textFields["Course Code"]
        courseField.tap()
        courseField.typeText("UIT100")

        let instructorField = app.textFields["Instructor"]
        instructorField.tap()
        instructorField.typeText("QA Bot")

        app.navigationBars.buttons["Add"].tap()

        app.tabBars.buttons["Learn"].tap()

        let learnHeadline = app.staticTexts["Flashcards"]
        XCTAssertTrue(learnHeadline.waitForExistence(timeout: 2))

        let placeholder = app.staticTexts["Add a lecture to generate study prompts."]
        XCTAssertTrue(placeholder.exists)

        app.tabBars.buttons["Classes"].tap()
    }
}
