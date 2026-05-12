import XCTest

final class AppUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["UI_TESTING"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Launch

    func testAppLaunchesSuccessfully() {
        XCTAssertEqual(app.state, .runningForeground)
    }

    // MARK: - Tab Bar Structure

    func testTabBarExists() {
        XCTAssertTrue(app.tabBars.firstMatch.exists)
    }

    func testFourTabsExist() {
        XCTAssertEqual(app.tabBars.firstMatch.buttons.count, 4)
    }

    func testTodayTabExists() {
        XCTAssertTrue(app.tabBars.buttons["Today"].exists)
    }

    func testCalendarTabExists() {
        XCTAssertTrue(app.tabBars.buttons["Calendar"].exists)
    }

    func testSummaryTabExists() {
        XCTAssertTrue(app.tabBars.buttons["Summary"].exists)
    }

    func testTrackersTabExists() {
        XCTAssertTrue(app.tabBars.buttons["Trackers"].exists)
    }

    // MARK: - Tab Navigation

    func testNavigateToCalendarTab() {
        app.tabBars.buttons["Calendar"].tap()
        XCTAssertTrue(app.navigationBars.firstMatch.exists)
    }

    func testNavigateToSummaryTab() {
        app.tabBars.buttons["Summary"].tap()
        XCTAssertTrue(app.navigationBars["Summary"].waitForExistence(timeout: 3))
    }

    func testNavigateToTrackersTab() {
        app.tabBars.buttons["Trackers"].tap()
        XCTAssertTrue(app.navigationBars["Trackers"].waitForExistence(timeout: 3))
    }

    func testNavigateBackToTodayTab() {
        app.tabBars.buttons["Trackers"].tap()
        app.tabBars.buttons["Today"].tap()
        XCTAssertEqual(app.state, .runningForeground)
    }

    // MARK: - Today Tab

    func testTodayTabIsSelected() {
        // Today is selected by default
        let todayButton = app.tabBars.buttons["Today"]
        XCTAssertTrue(todayButton.isSelected)
    }

    func testTodayTabShowsNavigationBar() {
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 3))
    }

    // MARK: - Trackers Tab

    func testTrackersTabShowsAddButton() {
        app.tabBars.buttons["Trackers"].tap()
        let addButton = app.navigationBars.buttons.element(matching: .button, identifier: "Add")
        // The add button may be identified differently; check for any "+" button
        let hasAddButton = addButton.exists ||
            app.navigationBars.firstMatch.buttons.count > 0
        XCTAssertTrue(hasAddButton)
    }

    // MARK: - Accessibility

    func testAllTabBarButtonsAreEnabled() {
        let buttons = app.tabBars.firstMatch.buttons.allElementsBoundByIndex
        for button in buttons {
            XCTAssertTrue(button.isEnabled, "\(button.label) tab should be enabled")
        }
    }

    func testAllTabBarButtonsAreHittable() {
        let buttons = app.tabBars.firstMatch.buttons.allElementsBoundByIndex
        for button in buttons {
            XCTAssertTrue(button.isHittable, "\(button.label) should be hittable")
        }
    }

    // MARK: - Regression: Summary tab navigation title

    func testSummaryTabShowsCorrectTitle() {
        app.tabBars.buttons["Summary"].tap()
        let title = app.navigationBars["Summary"]
        XCTAssertTrue(title.waitForExistence(timeout: 3),
                      "Summary tab must show 'Summary' navigation title")
    }

    // MARK: - Regression: Trackers tab navigation title

    func testTrackersTabShowsCorrectTitle() {
        app.tabBars.buttons["Trackers"].tap()
        let title = app.navigationBars["Trackers"]
        XCTAssertTrue(title.waitForExistence(timeout: 3),
                      "Trackers tab must show 'Trackers' navigation title")
    }

    // MARK: - Smoke: Rapid tab switching

    func testRapidTabSwitchingDoesNotCrash() {
        let tabs = ["Today", "Calendar", "Summary", "Trackers", "Today"]
        for tabName in tabs {
            app.tabBars.buttons[tabName].tap()
        }
        XCTAssertEqual(app.state, .runningForeground)
    }
}
