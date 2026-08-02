import XCTest

extension CloudBakeOwnerUITests {
    func testCustomerPreviousOrderCanStartANewDraft() throws {
        let app = makeApp(initialDestination: "customers")
        let transitionTimeout: TimeInterval = 15
        app.launchEnvironment["CLOUDBAKE_SEED_ORDER_CUSTOMER_LINK_FIXTURE"] = "1"
        app.launch()

        assertScreenVisible("screen.customers", in: app, timeout: transitionTimeout)
        tapWhenReady(
            app.buttons.matching(
                NSPredicate(format: "identifier BEGINSWITH %@", "customers.item.")
            ).firstMatch,
            timeout: transitionTimeout
        )
        let repeatButton = app.buttons["customers.detail.order.repeat.order-ui-fixture-customer-link"]
        scrollToHittable(repeatButton, in: app, timeout: transitionTimeout)
        tapWhenReady(repeatButton, timeout: transitionTimeout)

        XCTAssertTrue(app.navigationBars["Add Order"].waitForExistence(timeout: transitionTimeout))
        XCTAssertEqual(app.textFields["orders.form.title"].value as? String, "Vanilla Birthday")
        let customerName = app.textFields["orders.form.customerName"]
        scrollToHittable(customerName, in: app, timeout: transitionTimeout)
        XCTAssertEqual(customerName.value as? String, "Amy")
        scrollToHittable(app.textFields["orders.form.quotedPrice"], in: app, timeout: transitionTimeout)
        XCTAssertNotEqual(app.textFields["orders.form.quotedPrice"].value as? String, "0")
    }

    func testCustomerCanBeAddedAndViewed() throws {
        let app = makeApp(initialDestination: "customers")
        app.launch()

        assertScreenVisible("screen.customers", in: app, timeout: 5)
        XCTAssertTrue(app.staticTexts["No customers yet"].waitForExistence(timeout: 5))

        addCustomer(named: "Amy", phone: "5550101", in: app)

        assertScreenVisible("screen.customers", in: app, timeout: 5)
        XCTAssertTrue(app.staticTexts["Amy"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["555-0101"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "customers.item.call.")).firstMatch.exists)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "customers.item.newOrder.")).firstMatch.exists)
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "customers.item."))
            .firstMatch
            .tap()

        XCTAssertTrue(app.buttons["customers.detail.done"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["customers.detail.call"].exists)
        XCTAssertFalse(app.buttons["customers.detail.message"].exists)
        XCTAssertFalse(app.buttons["customers.detail.newOrder"].exists)
        XCTAssertTrue(app.staticTexts["Phone"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["555-0101"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Birthday"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Allergies & Dietary"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Nuts"].waitForExistence(timeout: 5))
        app.buttons["customers.detail.done"].tap()

        let newOrderButton = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "customers.item.newOrder.")
        ).firstMatch
        XCTAssertTrue(newOrderButton.waitForExistence(timeout: 5))
        newOrderButton.tap()
        XCTAssertTrue(app.navigationBars["Add Order"].waitForExistence(timeout: 5))
        let customerRecord = app.buttons["orders.form.customerRecord"]
        scrollToHittable(customerRecord, in: app, timeout: 10)
        XCTAssertTrue(customerRecord.label.contains("Amy"))
    }

    func testCustomerAddOffersContactsImportAndManualEntry() throws {
        let app = makeApp(initialDestination: "customers")
        let transitionTimeout: TimeInterval = 15
        app.launch()

        assertScreenVisible("screen.customers", in: app, timeout: transitionTimeout)
        openCustomerAddMode(in: app, timeout: transitionTimeout)

        XCTAssertTrue(
            nativeDialogAction(
                labeled: "Import From Contacts",
                in: app
            ).waitForExistence(timeout: transitionTimeout)
        )
        selectManualCustomerEntry(in: app, timeout: transitionTimeout)
    }

    func testCustomerDuplicateWarningAppearsBeforeSaving() throws {
        let app = makeApp(initialDestination: "customers")
        let transitionTimeout: TimeInterval = 15
        app.launch()

        assertScreenVisible("screen.customers", in: app, timeout: transitionTimeout)
        addCustomer(named: "Amy", phone: "5550101", in: app)
        openManualCustomerForm(in: app, timeout: transitionTimeout)
        typeCustomerFormText("Amy", into: "customers.form.name", in: app, timeout: transitionTimeout)
        typeCustomerFormText("5550101", into: "customers.form.phone", in: app, timeout: transitionTimeout)
        tapWhenReady(app.buttons["customers.form.save"], timeout: transitionTimeout)

        XCTAssertTrue(
            app.staticTexts["Possible duplicate: Amy already exists. Tap Save again to add a separate customer."].waitForExistence(
                timeout: transitionTimeout))
    }

    func testCustomerCanBeEditedFromDetail() throws {
        let app = makeApp(initialDestination: "customers")
        app.launch()

        assertScreenVisible("screen.customers", in: app, timeout: 5)
        addCustomer(named: "Amy", phone: "5550101", in: app)
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "customers.item."))
            .firstMatch
            .tap()
        XCTAssertTrue(app.buttons["customers.detail.done"].waitForExistence(timeout: 5))

        app.buttons["customers.detail.edit"].tap()
        XCTAssertTrue(app.navigationBars["Edit Customer"].waitForExistence(timeout: 5))
        let nameField = app.textFields["customers.form.name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 3))
        nameField.typeText("Amy B")
        app.buttons["customers.form.save"].tap()

        XCTAssertTrue(app.buttons["customers.detail.done"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Amy B"].waitForExistence(timeout: 5))
    }

    func testCustomerCanBeDeletedFromDetail() throws {
        let app = makeApp(initialDestination: "customers")
        let transitionTimeout: TimeInterval = 15
        app.launch()

        assertScreenVisible("screen.customers", in: app, timeout: transitionTimeout)
        addCustomer(named: "Amy", phone: "5550101", in: app)
        let customerRow = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "customers.item.")).firstMatch
        tapWhenReady(customerRow, timeout: transitionTimeout)
        XCTAssertTrue(app.buttons["customers.detail.done"].waitForExistence(timeout: transitionTimeout))

        tapWhenReady(app.buttons["customers.detail.delete"], timeout: transitionTimeout)
        XCTAssertTrue(app.staticTexts["Delete Customer?"].waitForExistence(timeout: transitionTimeout))
        tapWhenReady(
            nativeDialogAction(
                identifiedBy: "customers.delete.confirm",
                in: app
            ),
            timeout: transitionTimeout
        )

        assertScreenVisible("screen.customers", in: app, timeout: transitionTimeout)
        XCTAssertTrue(app.staticTexts["No customers yet"].waitForExistence(timeout: transitionTimeout))
    }
}
