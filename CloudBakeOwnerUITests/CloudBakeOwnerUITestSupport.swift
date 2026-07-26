import XCTest

extension CloudBakeOwnerUITests {
    func makeApp(initialDestination: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["CLOUDBAKE_USE_IN_MEMORY_DATABASE"] = "1"
        if let initialDestination {
            app.launchEnvironment["CLOUDBAKE_INITIAL_DESTINATION"] = initialDestination
        }
        return app
    }

    func openDashboardDestination(
        _ title: String,
        in app: XCUIApplication,
        timeout: TimeInterval = 10,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let identifier: String
        let screenIdentifier: String
        switch title {
        case "Orders":
            identifier = "bottom.navigation.orders"
            screenIdentifier = "screen.orders"
        case "Inventory":
            identifier = "bottom.navigation.inventory"
            screenIdentifier = "screen.inventory"
        case "More":
            identifier = "bottom.navigation.more"
            screenIdentifier = "screen.more"
        case "Recipes":
            identifier = "navigation.recipes"
            screenIdentifier = "screen.recipes"
        case "Designs":
            identifier = "navigation.designs"
            screenIdentifier = "screen.designs"
        case "Customers":
            identifier = "navigation.customers"
            screenIdentifier = "screen.customers"
        case "Settings":
            identifier = "navigation.settings"
            screenIdentifier = "screen.settings"
        case "Reminders":
            identifier = "navigation.reminders"
            screenIdentifier = "screen.reminders"
        case "Reports":
            identifier = "navigation.reports"
            screenIdentifier = "screen.reports"
        default:
            XCTFail("Unsupported dashboard destination: \(title)", file: file, line: line)
            return
        }

        let destinationButton: XCUIElement
        if title == "Recipes"
            || title == "Customers"
            || title == "Designs"
            || title == "Reminders"
            || title == "Reports"
            || title == "Settings" {
            let moreTab = app.buttons["bottom.navigation.more"]
            tapWhenReady(moreTab, timeout: timeout, file: file, line: line)
            assertScreenVisible("screen.more", in: app, timeout: timeout, file: file, line: line)
            destinationButton = app.buttons[identifier]
            let moreScroll = app.scrollViews["screen.more"]
            XCTAssertTrue(
                moreScroll.waitForExistence(timeout: timeout),
                "More screen scroll view was not available.",
                file: file,
                line: line
            )
            scrollToHittable(
                destinationButton,
                in: app,
                scrollContainer: moreScroll,
                timeout: timeout,
                file: file,
                line: line
            )
            tapScrollableAction(
                destinationButton,
                in: moreScroll,
                waitingFor: app.descendants(matching: .any)[screenIdentifier],
                in: app,
                timeout: timeout,
                file: file,
                line: line
            )
            return
        } else {
            destinationButton = app.buttons[identifier]
        }
        XCTAssertTrue(
            destinationButton.waitForExistence(timeout: 2),
            "Dashboard destination \(title) did not exist before scrolling.",
            file: file,
            line: line
        )
        let navigationDeadline = Date().addingTimeInterval(timeout)
        repeat {
            scrollToHittable(destinationButton, in: app, timeout: timeout, file: file, line: line)
            tapWhenReady(destinationButton, timeout: timeout, file: file, line: line)

            if app.descendants(matching: .any)[screenIdentifier].waitForExistence(timeout: 3) {
                return
            }
        } while Date() < navigationDeadline

        assertScreenVisible(screenIdentifier, in: app, timeout: 1, file: file, line: line)
    }

    @discardableResult
    func expandSettingsSection(
        _ disclosureIdentifier: String,
        revealing destination: XCUIElement,
        in app: XCUIApplication,
        timeout: TimeInterval = 10,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        let settingsScroll = app.scrollViews["screen.settings"]
        XCTAssertTrue(
            settingsScroll.waitForExistence(timeout: timeout),
            "Settings scroll view was not available.",
            file: file,
            line: line
        )
        tapScrollableAction(
            app.buttons[disclosureIdentifier],
            in: settingsScroll,
            waitingFor: destination,
            in: app,
            timeout: timeout,
            file: file,
            line: line
        )
        return settingsScroll
    }

    func assertDashboardVisible(
        in app: XCUIApplication,
        timeout: TimeInterval = 10,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            app.scrollViews["screen.dashboard"].waitForExistence(timeout: timeout),
            "Dashboard screen was not visible.",
            file: file,
            line: line
        )
    }

    func assertScreenVisible(
        _ identifier: String,
        in app: XCUIApplication,
        timeout: TimeInterval = 10,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let screen = app.descendants(matching: .any)[identifier]
        XCTAssertTrue(screen.waitForExistence(timeout: timeout), "Screen \(identifier) was not visible.", file: file, line: line)
    }

    func returnToDashboard(
        in app: XCUIApplication,
        timeout: TimeInterval = 10,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let homeTab = app.buttons["bottom.navigation.dashboard"]
        if homeTab.waitForExistence(timeout: 1) {
            tapWhenReady(homeTab, timeout: timeout, file: file, line: line)
            assertDashboardVisible(in: app, timeout: timeout, file: file, line: line)
            return
        }

        let styledBackButton = app.buttons["cloudBake.back"]
        let backButton = styledBackButton.waitForExistence(timeout: 1)
            ? styledBackButton
            : app.navigationBars.buttons.element(boundBy: 0)
        tapWhenReady(backButton, timeout: timeout, file: file, line: line)
        assertDashboardVisible(in: app, timeout: timeout, file: file, line: line)
    }
}
