import XCTest

extension CloudBakeOwnerUITests {
    func testCustomerCanBeAddedAndViewed() throws {
        let app = makeApp(initialDestination: "customers")
        app.launch()

        assertScreenVisible("screen.customers", in: app, timeout: 5)
        XCTAssertTrue(app.staticTexts["No customers yet"].waitForExistence(timeout: 5))

        addCustomer(named: "Amy", phone: "5550101", in: app)

        assertScreenVisible("screen.customers", in: app, timeout: 5)
        XCTAssertTrue(app.staticTexts["Amy"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["555-0101"].waitForExistence(timeout: 5))
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "customers.item."))
            .firstMatch
            .tap()

        XCTAssertTrue(app.buttons["customers.detail.done"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["customers.detail.call"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["customers.detail.message"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["customers.detail.newOrder"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Phone"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["555-0101"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Birthday"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Allergies & Dietary"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Nuts"].waitForExistence(timeout: 5))
    }

    func testCustomerAddOffersContactsImportAndManualEntry() throws {
        let app = makeApp(initialDestination: "customers")
        let transitionTimeout: TimeInterval = 15
        app.launch()

        assertScreenVisible("screen.customers", in: app, timeout: transitionTimeout)
        tapWhenReady(app.buttons["customers.add"], timeout: transitionTimeout)

        XCTAssertTrue(app.buttons["Import From Contacts"].waitForExistence(timeout: transitionTimeout))
        tapWhenReady(app.buttons["Enter Manually"], timeout: transitionTimeout)
        XCTAssertTrue(app.navigationBars["Add Customer"].waitForExistence(timeout: transitionTimeout))
    }

    func testCustomerDuplicateWarningAppearsBeforeSaving() throws {
        let app = makeApp(initialDestination: "customers")
        let transitionTimeout: TimeInterval = 15
        app.launch()

        assertScreenVisible("screen.customers", in: app, timeout: transitionTimeout)
        addCustomer(named: "Amy", phone: "5550101", in: app)
        tapWhenReady(app.buttons["customers.add"], timeout: transitionTimeout)
        tapWhenReady(app.buttons["Enter Manually"], timeout: transitionTimeout)
        XCTAssertTrue(app.navigationBars["Add Customer"].waitForExistence(timeout: transitionTimeout))
        typeText("Amy", into: app.textFields["customers.form.name"], timeout: transitionTimeout)
        typeText("5550101", into: app.textFields["customers.form.phone"], timeout: transitionTimeout)
        tapWhenReady(app.buttons["customers.form.save"], timeout: transitionTimeout)

        XCTAssertTrue(app.staticTexts["Possible duplicate: Amy already exists. Tap Save again to add a separate customer."].waitForExistence(timeout: transitionTimeout))
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
        tapWhenReady(app.buttons["customers.delete.confirm"], timeout: transitionTimeout)

        assertScreenVisible("screen.customers", in: app, timeout: transitionTimeout)
        XCTAssertTrue(app.staticTexts["No customers yet"].waitForExistence(timeout: transitionTimeout))
    }
}
