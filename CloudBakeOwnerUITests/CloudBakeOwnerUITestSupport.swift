import XCTest

extension CloudBakeOwnerUITests {
    func makeApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["CLOUDBAKE_USE_IN_MEMORY_DATABASE"] = "1"
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
        switch title {
        case "Orders":
            identifier = "dashboard.tab.orders"
        case "Inventory":
            identifier = "dashboard.tab.inventory"
        case "Recipes":
            identifier = "dashboard.tab.recipes"
        case "Designs":
            identifier = "dashboard.soon.designs"
        case "Customers":
            identifier = "navigation.customers"
        case "Settings":
            identifier = "navigation.settings"
        default:
            XCTFail("Unsupported dashboard destination: \(title)", file: file, line: line)
            return
        }

        let destinationButton: XCUIElement
        if title == "Customers" || title == "Settings" {
            let dashboard = app.scrollViews["screen.dashboard"]
            for _ in 0..<4 where !app.staticTexts[title].exists {
                dashboard.swipeUp()
            }
            destinationButton = app.staticTexts[title]
        } else if identifier.hasPrefix("dashboard.tab.") {
            destinationButton = app.buttons.matching(NSPredicate(format: "label == %@", title)).firstMatch
        } else {
            destinationButton = app.buttons[identifier]
        }
        XCTAssertTrue(
            destinationButton.waitForExistence(timeout: 2),
            "Dashboard destination \(title) did not exist before scrolling.",
            file: file,
            line: line
        )
        scrollToHittable(destinationButton, in: app, timeout: timeout, file: file, line: line)
        tapWhenReady(destinationButton, timeout: timeout, file: file, line: line)
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
        let homeTab = app.buttons["navigation.dashboard"]
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

    func addInventoryItem(
        named name: String,
        currentQuantity: String,
        minimumQuantity: String,
        in app: XCUIApplication
    ) {
        tapWhenReady(app.buttons["inventory.add"])
        XCTAssertTrue(app.navigationBars["Add Item"].waitForExistence(timeout: 5))
        typeText(name, into: app.textFields["inventory.form.name"])
        typeText(currentQuantity, into: app.textFields["inventory.form.currentQuantity"])
        typeText(minimumQuantity, into: app.textFields["inventory.form.minimumQuantity"])
        tapWhenReady(app.buttons["inventory.form.save"])
        XCTAssertTrue(app.navigationBars["Inventory"].waitForExistence(timeout: 10))
    }

    func addOrder(
        named name: String,
        notes: String,
        customerName: String,
        quotedPrice: String? = nil,
        depositPaid: String? = nil,
        paymentNotes: String? = nil,
        in app: XCUIApplication,
        timeout: TimeInterval = 15
    ) {
        tapWhenReady(app.buttons["orders.add"])
        XCTAssertTrue(app.navigationBars["Add Order"].waitForExistence(timeout: timeout))
        typeText(name, into: app.textFields["orders.form.title"])
        typeText(notes, into: app.textFields["orders.form.cakeNotes"])
        typeText(customerName, into: app.textFields["orders.form.customerName"])
        if let quotedPrice {
            scrollToHittable(app.textFields["orders.form.quotedPrice"], in: app, timeout: timeout)
            typeText(quotedPrice, into: app.textFields["orders.form.quotedPrice"])
        }
        if let depositPaid {
            scrollToHittable(app.textFields["orders.form.depositPaid"], in: app, timeout: timeout)
            typeText(depositPaid, into: app.textFields["orders.form.depositPaid"])
        }
        if let paymentNotes {
            scrollToHittable(app.textFields["orders.form.paymentNotes"], in: app, timeout: timeout)
            typeText(paymentNotes, into: app.textFields["orders.form.paymentNotes"])
        }
        tapWhenReady(app.buttons["orders.form.save"])
        XCTAssertTrue(app.navigationBars["Orders"].waitForExistence(timeout: timeout))
    }

    func addRecipe(named name: String, notes: String, in app: XCUIApplication) {
        app.buttons["recipes.add"].tap()
        XCTAssertTrue(app.navigationBars["Add Recipe"].waitForExistence(timeout: 5))
        app.textFields["recipes.form.name"].tap()
        app.textFields["recipes.form.name"].typeText(name)
        app.textFields["recipes.form.notes"].tap()
        app.textFields["recipes.form.notes"].typeText(notes)
        app.buttons["recipes.form.save"].tap()
        XCTAssertTrue(app.navigationBars["Recipes"].waitForExistence(timeout: 5))
    }

    func addCustomer(named name: String, phone: String, in app: XCUIApplication) {
        XCTAssertTrue(app.navigationBars["Customers"].waitForExistence(timeout: 10))
        tapWhenReady(app.buttons["customers.add"])
        XCTAssertTrue(app.buttons["Enter Manually"].waitForExistence(timeout: 5))
        tapWhenReady(app.buttons["Enter Manually"])
        XCTAssertTrue(app.navigationBars["Add Customer"].waitForExistence(timeout: 5))
        typeText(name, into: app.textFields["customers.form.name"])
        typeText(phone, into: app.textFields["customers.form.phone"])
        typeText("amy@example.com", into: app.textFields["customers.form.email"])
        typeText("10 Cake Street", into: app.textFields["customers.form.address"])
        let importantDateField = app.textFields["customers.form.importantDate.label"]
        scrollToHittable(importantDateField, in: app)
        typeText("Birthday", into: importantDateField)
        let allergiesField = app.textFields["customers.form.allergies"]
        scrollToHittable(allergiesField, in: app)
        typeText("Nuts", into: allergiesField)
        tapWhenReady(app.buttons["customers.form.save"])
        XCTAssertTrue(app.navigationBars["Customers"].waitForExistence(timeout: 10))
    }

    func adjustFirstInventoryItem(by quantity: String, in app: XCUIApplication) {
        let row = firstEditableInventoryRow(in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.swipeRight()
        app.buttons["Adjust"].tap()
        XCTAssertTrue(app.navigationBars["Adjust Stock"].waitForExistence(timeout: 5))
        app.textFields["inventory.adjust.quantity"].tap()
        app.textFields["inventory.adjust.quantity"].typeText(quantity)
        app.buttons["inventory.adjust.save"].tap()
        XCTAssertTrue(app.navigationBars["Inventory"].waitForExistence(timeout: 5))
    }

    func consumeFirstInventoryItem(by quantity: String, in app: XCUIApplication) {
        let row = firstEditableInventoryRow(in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.swipeRight()
        app.buttons["Use"].tap()
        XCTAssertTrue(app.navigationBars["Use Stock"].waitForExistence(timeout: 5))
        app.textFields["inventory.consume.quantity"].tap()
        app.textFields["inventory.consume.quantity"].typeText(quantity)
        app.buttons["inventory.consume.save"].tap()
        XCTAssertTrue(app.navigationBars["Inventory"].waitForExistence(timeout: 5))
    }

    func firstEditableInventoryRow(in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "inventory.item.view.")).firstMatch
    }

    func inventoryRow(named name: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
                "inventory.item.view.",
                name
            )
        )
        .firstMatch
    }

    func archivedInventoryRow(named name: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
                "inventory.archived.item.",
                name
            )
        )
        .firstMatch
    }

    func tapWhenReady(
        _ element: XCUIElement,
        timeout: TimeInterval = 10,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Element did not exist before tap.", file: file, line: line)
        let hittable = NSPredicate(format: "isHittable == true")
        let expectation = XCTNSPredicateExpectation(predicate: hittable, object: element)
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation], timeout: timeout),
            .completed,
            "Element was not hittable before tap.",
            file: file,
            line: line
        )
        element.tap()
    }

    func tapExisting(
        _ element: XCUIElement,
        timeout: TimeInterval = 10,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let target = element.firstMatch
        XCTAssertTrue(target.waitForExistence(timeout: timeout), "Element did not exist before tap.", file: file, line: line)
        target.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    func typeText(
        _ text: String,
        into element: XCUIElement,
        timeout: TimeInterval = 10,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        tapWhenReady(element, timeout: timeout, file: file, line: line)
        element.typeText(text)
    }

    func dismissKeyboard(in app: XCUIApplication) {
        guard app.keyboards.firstMatch.exists else { return }
        if app.keyboards.buttons["Return"].exists {
            app.keyboards.buttons["Return"].tap()
        } else if app.keyboards.buttons["Done"].exists {
            app.keyboards.buttons["Done"].tap()
        } else {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)).tap()
        }
    }

    func assertExistsAfterScrolling(
        _ element: XCUIElement,
        in app: XCUIApplication,
        timeout: TimeInterval = 10,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let deadline = Date().addingTimeInterval(timeout)
        while !element.exists && Date() < deadline {
            app.swipeUp()
            _ = element.waitForExistence(timeout: 1)
        }
        XCTAssertTrue(element.exists, "Element did not exist after scrolling.", file: file, line: line)
    }

    func scrollToHittable(
        _ element: XCUIElement,
        in app: XCUIApplication,
        timeout: TimeInterval = 10,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let deadline = Date().addingTimeInterval(timeout)
        while (!element.exists || !element.isHittable) && Date() < deadline {
            app.swipeUp()
            _ = element.waitForExistence(timeout: 1)
        }
        XCTAssertTrue(element.exists, "Element did not exist after scrolling.", file: file, line: line)
        XCTAssertTrue(element.isHittable, "Element was not hittable after scrolling.", file: file, line: line)
    }

    func scrollToTop(in app: XCUIApplication) {
        for _ in 0..<3 {
            app.swipeDown()
        }
    }
}
