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
        default:
            XCTFail("Unsupported dashboard destination: \(title)", file: file, line: line)
            return
        }

        let destinationButton: XCUIElement
        if title == "Recipes" || title == "Customers" || title == "Designs" || title == "Settings" {
            let moreTab = app.buttons["bottom.navigation.more"]
            tapWhenReady(moreTab, timeout: timeout, file: file, line: line)
            assertScreenVisible("screen.more", in: app, timeout: timeout, file: file, line: line)
            destinationButton = app.buttons[identifier]
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

    func addInventoryItem(
        named name: String,
        currentQuantity: String,
        minimumQuantity: String,
        in app: XCUIApplication,
        timeout: TimeInterval = 10
    ) {
        tapInventoryHeaderAction(
            "inventory.add",
            in: app,
            waitingFor: app.navigationBars["Add Item"],
            timeout: timeout
        )
        let formScroll = app.descendants(matching: .any)["inventory.form.scroll"]
        XCTAssertTrue(formScroll.waitForExistence(timeout: timeout))

        let nameField = app.textFields["inventory.form.name"]
        scrollToHittable(nameField, in: app, scrollContainer: formScroll, timeout: timeout)
        typeText(name, into: nameField, timeout: timeout)
        dismissKeyboard(in: app)

        let currentQuantityField = app.textFields["inventory.form.currentQuantity"]
        scrollToHittable(
            currentQuantityField,
            in: app,
            scrollContainer: formScroll,
            timeout: timeout
        )
        typeText(currentQuantity, into: currentQuantityField, timeout: timeout)
        dismissKeyboard(in: app)

        let minimumQuantityField = app.textFields["inventory.form.minimumQuantity"]
        scrollToHittable(
            minimumQuantityField,
            in: app,
            scrollContainer: formScroll,
            timeout: timeout
        )
        typeText(minimumQuantity, into: minimumQuantityField, timeout: timeout)
        dismissKeyboard(in: app)

        let saveButton = app.buttons["inventory.form.save"]
        scrollToHittable(saveButton, in: app, scrollContainer: formScroll, timeout: timeout)
        tapWhenReady(saveButton, timeout: timeout)
        assertScreenVisible("screen.inventory", in: app, timeout: timeout)
    }

    func tapInventoryHeaderAction(
        _ identifier: String,
        in app: XCUIApplication,
        waitingFor destination: XCUIElement? = nil,
        timeout: TimeInterval = 10,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        tapHeaderAction(
            identifier,
            in: app,
            waitingFor: destination,
            timeout: timeout,
            file: file,
            line: line
        )
    }

    func tapHeaderAction(
        _ identifier: String,
        in app: XCUIApplication,
        waitingFor destination: XCUIElement? = nil,
        timeout: TimeInterval = 10,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let directAction = app.buttons[identifier]
        if directAction.waitForExistence(timeout: 1), directAction.isHittable {
            tapWhenReady(directAction, timeout: timeout, file: file, line: line)
        } else {
            let moreActionsButton = app.buttons["screen.actions.more"]
            tapWhenReady(moreActionsButton, timeout: timeout, file: file, line: line)
            tapWhenReady(app.buttons[identifier], timeout: timeout, file: file, line: line)
        }

        guard let destination else { return }
        XCTAssertTrue(
            destination.waitForExistence(timeout: timeout),
            "Header action did not reach its destination. Hierarchy: \(app.debugDescription)",
            file: file,
            line: line
        )
    }

    func addOrder(
        named name: String,
        notes: String,
        customerName: String,
        cakeMessage: String? = nil,
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
        dismissKeyboard(in: app)
        typeText(customerName, into: app.textFields["orders.form.customerName"])
        dismissKeyboard(in: app)
        if let cakeMessage {
            scrollToHittable(app.textFields["orders.form.cakeMessage"], in: app, timeout: timeout)
            typeText(cakeMessage, into: app.textFields["orders.form.cakeMessage"], timeout: timeout)
            dismissKeyboard(in: app)
            swipeUpInPrimaryScrollableArea(in: app)
        }
        if let quotedPrice {
            scrollToHittable(app.textFields["orders.form.quotedPrice"], in: app, timeout: timeout)
            typeText(quotedPrice, into: app.textFields["orders.form.quotedPrice"])
            dismissKeyboard(in: app)
        }
        if let depositPaid {
            scrollToHittable(app.textFields["orders.form.depositPaid"], in: app, timeout: timeout)
            typeText(depositPaid, into: app.textFields["orders.form.depositPaid"])
            dismissKeyboard(in: app)
        }
        if let paymentNotes {
            scrollToHittable(app.textFields["orders.form.paymentNotes"], in: app, timeout: timeout)
            typeText(paymentNotes, into: app.textFields["orders.form.paymentNotes"])
            dismissKeyboard(in: app)
        }
        tapWhenReady(app.buttons["orders.form.save"])
        assertScreenVisible("screen.orders", in: app, timeout: timeout)
    }

    func addRecipe(named name: String, notes: String, in app: XCUIApplication) {
        app.buttons["recipes.add"].tap()
        XCTAssertTrue(app.navigationBars["Add Recipe"].waitForExistence(timeout: 5))
        app.textFields["recipes.form.name"].tap()
        app.textFields["recipes.form.name"].typeText(name)
        app.textFields["recipes.form.notes"].tap()
        app.textFields["recipes.form.notes"].typeText(notes)
        app.buttons["recipes.form.save"].tap()
        assertScreenVisible("screen.recipes", in: app, timeout: 5)
    }

    func addCustomer(named name: String, phone: String, in app: XCUIApplication) {
        assertScreenVisible("screen.customers", in: app, timeout: 10)
        openManualCustomerForm(in: app)
        typeText(name, into: app.textFields["customers.form.name"])
        typeText(phone, into: app.textFields["customers.form.phone"])
        typeText("amy@example.com", into: app.textFields["customers.form.email"])
        typeText("10 Cake Street", into: app.textFields["customers.form.address"])
        dismissKeyboard(in: app)
        let importantDateField = app.textFields["customers.form.importantDate.label"]
        scrollToHittable(importantDateField, in: app)
        typeText("Birthday", into: importantDateField)
        dismissKeyboard(in: app)
        let allergiesField = app.textFields["customers.form.allergies"]
        scrollToHittable(allergiesField, in: app)
        typeText("Nuts", into: allergiesField)
        tapWhenReady(app.buttons["customers.form.save"])
        assertScreenVisible("screen.customers", in: app, timeout: 10)
    }

    func openManualCustomerForm(
        in app: XCUIApplication,
        timeout: TimeInterval = 10
    ) {
        openCustomerAddMode(in: app, timeout: timeout)
        selectManualCustomerEntry(in: app, timeout: timeout)
    }

    func openCustomerAddMode(
        in app: XCUIApplication,
        timeout: TimeInterval = 10
    ) {
        let manualEntry = app.buttons["customers.add.manual"]
        tapWhenReady(
            app.buttons["customers.add"],
            waitingFor: manualEntry,
            in: app,
            timeout: timeout
        )
    }

    func selectManualCustomerEntry(
        in app: XCUIApplication,
        timeout: TimeInterval = 10
    ) {
        tapWhenReady(
            app.buttons["customers.add.manual"],
            waitingFor: app.navigationBars["Add Customer"],
            in: app,
            timeout: timeout
        )
    }

    func adjustFirstInventoryItem(by quantity: String, in app: XCUIApplication) {
        tapWhenReady(firstEditableInventoryRow(in: app), timeout: 10)
        let adjustButton = app.buttons["inventory.detail.adjust"]
        XCTAssertTrue(adjustButton.waitForExistence(timeout: 5))
        adjustButton.tap()
        XCTAssertTrue(app.navigationBars["Adjust Stock"].waitForExistence(timeout: 5))
        app.textFields["inventory.adjust.quantity"].tap()
        app.textFields["inventory.adjust.quantity"].typeText(quantity)
        app.buttons["inventory.adjust.save"].tap()
        XCTAssertTrue(app.buttons["inventory.detail.done"].waitForExistence(timeout: 5))
        app.buttons["inventory.detail.done"].tap()
        assertScreenVisible("screen.inventory", in: app, timeout: 5)
    }

    func consumeFirstInventoryItem(by quantity: String, in app: XCUIApplication) {
        tapWhenReady(firstEditableInventoryRow(in: app), timeout: 10)
        let consumeButton = app.buttons["inventory.detail.consume"]
        XCTAssertTrue(consumeButton.waitForExistence(timeout: 5))
        consumeButton.tap()
        XCTAssertTrue(app.navigationBars["Use Stock"].waitForExistence(timeout: 5))
        app.textFields["inventory.consume.quantity"].tap()
        app.textFields["inventory.consume.quantity"].typeText(quantity)
        app.buttons["inventory.consume.save"].tap()
        XCTAssertTrue(app.buttons["inventory.detail.done"].waitForExistence(timeout: 5))
        app.buttons["inventory.detail.done"].tap()
        assertScreenVisible("screen.inventory", in: app, timeout: 5)
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

    func tapWhenReady(
        _ element: XCUIElement,
        waitingFor destination: XCUIElement,
        in app: XCUIApplication,
        timeout: TimeInterval = 10,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        tapWhenReady(element, timeout: timeout, file: file, line: line)
        XCTAssertTrue(
            destination.waitForExistence(timeout: timeout),
            "Tap did not reach the expected destination. Hierarchy: \(app.debugDescription)",
            file: file,
            line: line
        )
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
        let target = element.firstMatch
        XCTAssertTrue(target.waitForExistence(timeout: timeout), "Element did not exist before typing.", file: file, line: line)
        let hittable = NSPredicate(format: "isHittable == true")
        let hittableExpectation = XCTNSPredicateExpectation(predicate: hittable, object: target)
        XCTAssertEqual(
            XCTWaiter.wait(for: [hittableExpectation], timeout: timeout),
            .completed,
            "Element was not hittable before typing.",
            file: file,
            line: line
        )
        focusTextInput(target, timeout: timeout, file: file, line: line)
        target.typeText(text)
    }

    func focusTextInput(
        _ element: XCUIElement,
        timeout: TimeInterval = 10,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.16, dy: 0.5)).tap()
            if waitForKeyboardFocus(element, timeout: 0.8) {
                return
            }

            element.tap()
            if waitForKeyboardFocus(element, timeout: 0.8) {
                return
            }
        } while Date() < deadline

        XCTFail("Text input did not receive keyboard focus before typing.", file: file, line: line)
    }

    private func waitForKeyboardFocus(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let focusPredicate = NSPredicate(format: "hasKeyboardFocus == true")
        let focusExpectation = XCTNSPredicateExpectation(predicate: focusPredicate, object: element)
        if XCTWaiter.wait(for: [focusExpectation], timeout: timeout) == .completed {
            return true
        }

        let keyboard = XCUIApplication().keyboards.firstMatch
        if keyboard.exists || keyboard.waitForExistence(timeout: 0.2) {
            return true
        }

        return keyboard.exists
    }

    func dismissKeyboard(in app: XCUIApplication) {
        guard app.keyboards.firstMatch.exists else { return }
        let doneButton = app.buttons["Done"]
        if doneButton.exists, doneButton.isHittable {
            doneButton.tap()
        } else if app.keyboards.buttons["Done"].exists {
            app.keyboards.buttons["Done"].tap()
        } else if app.keyboards.buttons["Return"].exists {
            app.keyboards.buttons["Return"].tap()
        } else {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)).tap()
        }

        if app.keyboards.firstMatch.waitForExistence(timeout: 0.5) {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap()
        }
    }

    func assertExistsAfterScrolling(
        _ element: XCUIElement,
        in app: XCUIApplication,
        scrollContainer: XCUIElement? = nil,
        timeout: TimeInterval = 10,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let deadline = Date().addingTimeInterval(timeout)
        while !element.exists && Date() < deadline {
            swipeUpInPrimaryScrollableArea(in: app, preferred: scrollContainer)
            _ = element.waitForExistence(timeout: 1)
        }
        XCTAssertTrue(element.exists, "Element did not exist after scrolling.", file: file, line: line)
    }

    func scrollToHittable(
        _ element: XCUIElement,
        in app: XCUIApplication,
        scrollContainer: XCUIElement? = nil,
        timeout: TimeInterval = 10,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let deadline = Date().addingTimeInterval(timeout)
        while (!element.exists || !element.isHittable) && Date() < deadline {
            scrollTowardHittableElement(element, in: app, preferred: scrollContainer)
            _ = element.waitForExistence(timeout: 1)
        }
        XCTAssertTrue(element.exists, "Element did not exist after scrolling.", file: file, line: line)
        XCTAssertTrue(element.isHittable, "Element was not hittable after scrolling.", file: file, line: line)
    }

    func scrollToVisible(
        _ element: XCUIElement,
        in app: XCUIApplication,
        scrollContainer: XCUIElement? = nil,
        timeout: TimeInterval = 10,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let deadline = Date().addingTimeInterval(timeout)
        while (!element.exists || !isElementVisible(element, in: app)) && Date() < deadline {
            scrollTowardHittableElement(element, in: app, preferred: scrollContainer)
            _ = element.waitForExistence(timeout: 1)
        }
        XCTAssertTrue(element.exists, "Element did not exist after scrolling.", file: file, line: line)
        XCTAssertTrue(isElementVisible(element, in: app), "Element was not visible after scrolling.", file: file, line: line)
    }

    func scrollToTop(in app: XCUIApplication) {
        for _ in 0..<3 {
            app.swipeDown()
        }
    }

    private func swipeUpInPrimaryScrollableArea(
        in app: XCUIApplication,
        preferred scrollView: XCUIElement? = nil
    ) {
        if let scrollView, scrollView.exists {
            scrollView.swipeUp()
            return
        }

        let collectionView = app.collectionViews.firstMatch
        if collectionView.exists {
            collectionView.swipeUp()
            return
        }

        let scrollView = app.scrollViews.firstMatch
        if scrollView.exists {
            scrollView.swipeUp()
            return
        }

        app.swipeUp()
    }

    private func scrollTowardHittableElement(
        _ element: XCUIElement,
        in app: XCUIApplication,
        preferred scrollView: XCUIElement?
    ) {
        guard element.exists else {
            swipeUpInPrimaryScrollableArea(in: app, preferred: scrollView)
            return
        }

        let appFrame = app.windows.firstMatch.exists ? app.windows.firstMatch.frame : app.frame
        if element.frame.midY < appFrame.midY {
            dragPrimaryScrollableArea(
                in: app,
                preferred: scrollView,
                fromY: 0.34,
                toY: 0.58
            )
        } else {
            dragPrimaryScrollableArea(
                in: app,
                preferred: scrollView,
                fromY: 0.72,
                toY: 0.48
            )
        }
    }

    private func isElementVisible(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        guard element.exists, !element.frame.isEmpty else { return false }
        let appFrame = app.windows.firstMatch.exists ? app.windows.firstMatch.frame : app.frame
        return appFrame.intersects(element.frame)
    }

    private func swipeDownInPrimaryScrollableArea(in app: XCUIApplication) {
        let collectionView = app.collectionViews.firstMatch
        if collectionView.exists {
            collectionView.swipeDown()
            return
        }

        let scrollView = app.scrollViews.firstMatch
        if scrollView.exists {
            scrollView.swipeDown()
            return
        }

        app.swipeDown()
    }

    private func dragPrimaryScrollableArea(
        in app: XCUIApplication,
        preferred scrollView: XCUIElement? = nil,
        fromY: CGFloat,
        toY: CGFloat
    ) {
        let scrollable: XCUIElement
        if let scrollView, scrollView.exists {
            scrollable = scrollView
        } else {
            scrollable = app.collectionViews.firstMatch.exists
                ? app.collectionViews.firstMatch
                : app.scrollViews.firstMatch
        }
        guard scrollable.exists else {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: fromY))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: toY)))
            return
        }

        let start = scrollable.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: fromY))
        let end = scrollable.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: toY))
        start.press(forDuration: 0.05, thenDragTo: end)
    }
}
