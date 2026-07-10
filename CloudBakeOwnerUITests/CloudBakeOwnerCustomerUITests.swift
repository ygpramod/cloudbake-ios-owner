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
        XCTAssertTrue(app.staticTexts["5550101"].waitForExistence(timeout: 5))
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "customers.item."))
            .firstMatch
            .tap()

        XCTAssertTrue(app.buttons["customers.detail.done"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Name"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Phone"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Birthday"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Nuts"].waitForExistence(timeout: 5))
    }

    func testCustomerDetailUsesSplitViewOnIPad() throws {
        let app = makeApp(initialDestination: "customers")
        app.launchEnvironment["CLOUDBAKE_SEED_CUSTOMER_FIXTURE"] = "1"
        app.launch()

        guard app.windows.firstMatch.waitForExistence(timeout: 5),
              app.windows.firstMatch.frame.width >= 700 else {
            throw XCTSkip("Customer split view is only expected on regular-width iPad layouts.")
        }

        assertScreenVisible("screen.customers", in: app, timeout: 5)
        XCTAssertTrue(app.staticTexts["Select a customer"].waitForExistence(timeout: 5))

        XCTAssertTrue(app.staticTexts["Amy"].waitForExistence(timeout: 5))
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "customers.item."))
            .firstMatch
            .tap()

        XCTAssertTrue(app.buttons["customers.detail.edit"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["customers.detail.done"].exists)
        XCTAssertTrue(app.staticTexts["Name"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Phone"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Birthday"].waitForExistence(timeout: 5))
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
