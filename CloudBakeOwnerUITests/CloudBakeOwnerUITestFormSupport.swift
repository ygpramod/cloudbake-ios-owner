import XCTest

extension CloudBakeOwnerUITests {
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
        if let cakeMessage {
            let cakeMessageField = app.textFields["orders.form.cakeMessage"]
            scrollToHittable(cakeMessageField, in: app, timeout: timeout)
            typeText(cakeMessage, into: cakeMessageField, timeout: timeout)
            dismissKeyboard(in: app)
        }
        let customerNameField = app.textFields["orders.form.customerName"]
        scrollToHittable(customerNameField, in: app, timeout: timeout)
        typeText(customerName, into: customerNameField, timeout: timeout)
        dismissKeyboard(in: app)
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
        typeCustomerFormText(name, into: "customers.form.name", in: app)
        typeCustomerFormText(phone, into: "customers.form.phone", in: app)
        typeCustomerFormText("amy@example.com", into: "customers.form.email", in: app)
        typeCustomerFormText("10 Cake Street", into: "customers.form.address", in: app)
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

    func typeCustomerFormText(
        _ text: String,
        into identifier: String,
        in app: XCUIApplication,
        timeout: TimeInterval = 10,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let formScroll = app.descendants(matching: .any)["customers.form.scroll"]
        XCTAssertTrue(
            formScroll.waitForExistence(timeout: timeout),
            "Customer form did not expose its scroll container.",
            file: file,
            line: line
        )
        let field = app.textFields[identifier]
        scrollToHittable(
            field,
            in: app,
            scrollContainer: formScroll,
            timeout: timeout,
            file: file,
            line: line
        )
        typeText(text, into: field, timeout: timeout, file: file, line: line)
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
        let addButton = app.buttons["customers.add"]
        XCTAssertTrue(
            addButton.waitForExistence(timeout: timeout),
            "Customer add action was not available."
        )

        let addModeDialog = app.sheets.firstMatch
        for attempt in 0..<2 {
            addButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            if addModeDialog.waitForExistence(timeout: min(5, timeout)) {
                XCTAssertTrue(
                    app.staticTexts["Add Customer"].waitForExistence(timeout: timeout),
                    "Customer add choices did not include their title."
                )
                return
            }

            if attempt == 0 {
                app.activate()
            }
        }

        XCTFail("Customer add action did not present its entry choices.")
    }

    func selectManualCustomerEntry(
        in app: XCUIApplication,
        timeout: TimeInterval = 10
    ) {
        tapWhenReady(
            nativeDialogAction(
                labeled: "Enter Manually",
                in: app
            ),
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

}
