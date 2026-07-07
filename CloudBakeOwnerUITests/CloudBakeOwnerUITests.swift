import XCTest

final class CloudBakeOwnerUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAppLaunchesToDashboard() throws {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(app.navigationBars["CloudBake"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Upcoming orders"].exists)
        XCTAssertTrue(app.staticTexts["Low inventory"].exists)
    }

    func testPrimaryNavigationDestinationsAreReachable() throws {
        let app = makeApp()
        app.launch()

        for title in ["Orders", "Inventory", "Recipes", "Designs", "Customers", "Settings"] {
            let navigationLink = app.staticTexts[title]
            if !navigationLink.waitForExistence(timeout: 2) {
                app.swipeUp()
            }
            XCTAssertTrue(navigationLink.waitForExistence(timeout: 5), "Missing navigation link for \(title)")
            navigationLink.tap()
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5), "Missing screen for \(title)")
            app.navigationBars.buttons["CloudBake"].tap()
        }
    }

    func testOrderCanBeAddedAndListed() throws {
        let app = makeApp()
        let transitionTimeout: TimeInterval = 15
        app.launch()

        tapWhenReady(app.staticTexts["Orders"])
        XCTAssertTrue(app.navigationBars["Orders"].waitForExistence(timeout: transitionTimeout))
        XCTAssertTrue(app.staticTexts["No orders yet"].waitForExistence(timeout: transitionTimeout))

        addOrder(named: "Vanilla Birthday", notes: "Pink flowers", customerName: "Amy", in: app)

        XCTAssertTrue(app.navigationBars["Orders"].waitForExistence(timeout: transitionTimeout))
        XCTAssertTrue(app.staticTexts["Vanilla Birthday"].waitForExistence(timeout: transitionTimeout))
        XCTAssertTrue(app.staticTexts["Amy"].waitForExistence(timeout: transitionTimeout))
    }

    func testOrderCanBeOpenedFromListAndViewed() throws {
        let app = makeApp()
        let transitionTimeout: TimeInterval = 15
        app.launch()

        tapWhenReady(app.staticTexts["Orders"])
        XCTAssertTrue(app.navigationBars["Orders"].waitForExistence(timeout: transitionTimeout))

        addOrder(
            named: "Vanilla Birthday",
            notes: "Pink flowers",
            customerName: "Amy",
            quotedPrice: "125.50",
            depositPaid: "25.50",
            paymentNotes: "Bank transfer",
            in: app
        )

        XCTAssertTrue(app.navigationBars["Orders"].waitForExistence(timeout: transitionTimeout))
        XCTAssertTrue(app.staticTexts["Vanilla Birthday"].waitForExistence(timeout: transitionTimeout))
        let orderRow = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "orders.item."))
            .firstMatch
        tapWhenReady(orderRow)

        XCTAssertTrue(app.navigationBars["Vanilla Birthday"].waitForExistence(timeout: transitionTimeout))
        XCTAssertTrue(app.staticTexts["orders.detail.cake"].waitForExistence(timeout: transitionTimeout))
        assertExistsAfterScrolling(app.staticTexts["orders.detail.customerName"], in: app, timeout: transitionTimeout)
        assertExistsAfterScrolling(app.staticTexts["orders.detail.fulfillmentType"], in: app, timeout: transitionTimeout)
        assertExistsAfterScrolling(app.staticTexts["orders.detail.cakeNotes"], in: app, timeout: transitionTimeout)
        assertExistsAfterScrolling(app.staticTexts["orders.detail.paymentStatus"], in: app, timeout: transitionTimeout)
        assertExistsAfterScrolling(app.staticTexts["orders.detail.quotedPrice"], in: app, timeout: transitionTimeout)
        assertExistsAfterScrolling(app.staticTexts["orders.detail.depositPaid"], in: app, timeout: transitionTimeout)
        assertExistsAfterScrolling(app.staticTexts["orders.detail.balanceDue"], in: app, timeout: transitionTimeout)
        assertExistsAfterScrolling(app.staticTexts["orders.detail.paymentNotes"], in: app, timeout: transitionTimeout)
    }

    func testOrderDetailCanMarkPaymentPaid() throws {
        let app = makeApp()
        let transitionTimeout: TimeInterval = 15
        app.launch()

        tapWhenReady(app.staticTexts["Orders"], timeout: transitionTimeout)
        XCTAssertTrue(app.navigationBars["Orders"].waitForExistence(timeout: transitionTimeout))
        addOrder(
            named: "Payment Vanilla",
            notes: "Paid on pickup",
            customerName: "Amy",
            quotedPrice: "125",
            depositPaid: "25",
            in: app,
            timeout: transitionTimeout
        )

        let orderRow = app.buttons.matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
                "orders.item.",
                "Payment Vanilla"
            )
        )
            .firstMatch
        tapWhenReady(orderRow, timeout: transitionTimeout)
        XCTAssertTrue(app.navigationBars["Payment Vanilla"].waitForExistence(timeout: transitionTimeout))

        let paymentMenu = app.buttons["orders.detail.paymentStatusMenu"]
        assertExistsAfterScrolling(paymentMenu, in: app, timeout: transitionTimeout)
        tapWhenReady(paymentMenu, timeout: transitionTimeout)
        tapExisting(app.buttons["orders.detail.payment.paid"], timeout: transitionTimeout)

        let paymentStatus = app.staticTexts["orders.detail.paymentStatus"]
        assertExistsAfterScrolling(paymentStatus, in: app, timeout: transitionTimeout)
        XCTAssertTrue(paymentStatus.label.contains("Paid"))
        let depositPaid = app.staticTexts["orders.detail.depositPaid"]
        assertExistsAfterScrolling(depositPaid, in: app, timeout: transitionTimeout)
        XCTAssertTrue(depositPaid.label.contains("125"))
        let balanceDue = app.staticTexts["orders.detail.balanceDue"]
        assertExistsAfterScrolling(balanceDue, in: app, timeout: transitionTimeout)
        XCTAssertTrue(balanceDue.label.contains("0"))
    }

    func testOrderShowsDueRemindersAndReminderPlan() throws {
        let app = makeApp()
        let transitionTimeout: TimeInterval = 15
        let orderTitle = "Reminder Vanilla Birthday"
        app.launchEnvironment["CLOUDBAKE_SEED_ORDER_REMINDER_FIXTURE"] = "1"
        app.launch()

        tapWhenReady(app.staticTexts["Orders"])
        XCTAssertTrue(app.navigationBars["Orders"].waitForExistence(timeout: transitionTimeout))

        XCTAssertFalse(app.staticTexts["orders.remindersDue.header"].exists)
        let orderRow = app.buttons.matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
                "orders.item.",
                orderTitle
            )
        )
            .firstMatch
        assertExistsAfterScrolling(orderRow, in: app, timeout: transitionTimeout)
        tapWhenReady(orderRow, timeout: transitionTimeout)

        XCTAssertTrue(app.navigationBars[orderTitle].waitForExistence(timeout: transitionTimeout))
        assertExistsAfterScrolling(app.staticTexts["orders.detail.reminder.1"], in: app, timeout: transitionTimeout)
    }

    func testOrderCanBeEditedFromDetail() throws {
        let app = makeApp()
        let transitionTimeout: TimeInterval = 15
        app.launch()

        tapWhenReady(app.staticTexts["Orders"])
        XCTAssertTrue(app.navigationBars["Orders"].waitForExistence(timeout: transitionTimeout))
        addOrder(named: "Vanilla Birthday", notes: "Pink flowers", customerName: "Amy", in: app)

        tapWhenReady(
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "orders.item."))
                .firstMatch,
            timeout: transitionTimeout
        )
        XCTAssertTrue(app.navigationBars["Vanilla Birthday"].waitForExistence(timeout: transitionTimeout))
        tapWhenReady(app.buttons["orders.detail.edit"], timeout: transitionTimeout)
        XCTAssertTrue(app.navigationBars["Edit Order"].waitForExistence(timeout: transitionTimeout))

        let titleField = app.textFields["orders.form.title"]
        tapWhenReady(titleField, timeout: transitionTimeout)
        titleField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 30))
        titleField.typeText("Chocolate Birthday")

        let notesField = app.textFields["orders.form.cakeNotes"]
        tapWhenReady(notesField, timeout: transitionTimeout)
        notesField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 30))
        notesField.typeText("Gold leaf")

        tapWhenReady(app.buttons["orders.form.save"], timeout: transitionTimeout)

        XCTAssertTrue(app.navigationBars["Chocolate Birthday"].waitForExistence(timeout: transitionTimeout))
        XCTAssertTrue(app.staticTexts["orders.detail.cake"].waitForExistence(timeout: transitionTimeout))
        assertExistsAfterScrolling(app.staticTexts["orders.detail.cakeNotes"], in: app, timeout: transitionTimeout)
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Gold leaf"))
                .firstMatch
                .waitForExistence(timeout: transitionTimeout)
        )
    }

    func testOrderChecklistItemCanBeAddedAndCompleted() throws {
        let app = makeApp()
        let transitionTimeout: TimeInterval = 15
        app.launch()

        tapWhenReady(app.staticTexts["Orders"], timeout: transitionTimeout)
        XCTAssertTrue(app.navigationBars["Orders"].waitForExistence(timeout: transitionTimeout))
        addOrder(named: "Vanilla Birthday", notes: "Pink flowers", customerName: "Amy", in: app)

        tapWhenReady(
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "orders.item."))
                .firstMatch,
            timeout: transitionTimeout
        )
        XCTAssertTrue(app.navigationBars["Vanilla Birthday"].waitForExistence(timeout: transitionTimeout))

        let checklistTitle = app.textFields["orders.detail.checklist.title"]
        assertExistsAfterScrolling(checklistTitle, in: app, timeout: transitionTimeout)
        typeText("Crumb coat", into: checklistTitle, timeout: transitionTimeout)
        tapExisting(app.buttons["orders.detail.checklist.add"], timeout: transitionTimeout)

        let checklistItem = app.descendants(matching: .any).matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@",
                "orders.detail.checklist.item."
            )
        )
            .firstMatch
        XCTAssertTrue(checklistItem.waitForExistence(timeout: transitionTimeout))
        XCTAssertEqual(checklistItem.value as? String, "Incomplete")

        checklistItem.swipeLeft()
        let editButton = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "orders.detail.checklist.edit.")
        )
            .firstMatch
        tapExisting(editButton, timeout: transitionTimeout)
        XCTAssertTrue(app.navigationBars["Edit Checklist Item"].waitForExistence(timeout: transitionTimeout))
        let editTitle = app.textFields["orders.detail.checklist.edit.title"]
        tapWhenReady(editTitle, timeout: transitionTimeout)
        editTitle.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 20))
        editTitle.typeText("Final photo")
        tapWhenReady(app.buttons["orders.detail.checklist.edit.save"], timeout: transitionTimeout)
        XCTAssertTrue(app.navigationBars["Vanilla Birthday"].waitForExistence(timeout: transitionTimeout))
        XCTAssertTrue(checklistItem.label.contains("Final photo"))

        tapExisting(checklistItem, timeout: transitionTimeout)
        let completedState = NSPredicate(format: "value == %@", "Complete")
        let completedExpectation = XCTNSPredicateExpectation(predicate: completedState, object: checklistItem)
        if XCTWaiter.wait(for: [completedExpectation], timeout: 2) != .completed {
            tapExisting(checklistItem, timeout: transitionTimeout)
        }
        XCTAssertEqual(
            XCTWaiter.wait(
                for: [XCTNSPredicateExpectation(predicate: completedState, object: checklistItem)],
                timeout: transitionTimeout
            ),
            .completed
        )

        checklistItem.swipeLeft()
        let deleteButton = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "orders.detail.checklist.delete.")
        )
            .firstMatch
        tapExisting(deleteButton, timeout: transitionTimeout)
        XCTAssertTrue(app.staticTexts["orders.detail.checklist.empty"].waitForExistence(timeout: transitionTimeout))
    }

    func testOrderDetailShowsSavedOrderPhotos() throws {
        let app = makeApp()
        let transitionTimeout: TimeInterval = 15
        app.launchEnvironment["CLOUDBAKE_SEED_ORDER_PHOTO_FIXTURE"] = "1"
        app.launch()

        tapWhenReady(app.staticTexts["Orders"], timeout: transitionTimeout)
        XCTAssertTrue(app.navigationBars["Orders"].waitForExistence(timeout: transitionTimeout))

        let orderRow = app.buttons.matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
                "orders.item.",
                "Photo Vanilla Birthday"
            )
        )
            .firstMatch
        tapWhenReady(orderRow, timeout: transitionTimeout)

        XCTAssertTrue(app.navigationBars["Photo Vanilla Birthday"].waitForExistence(timeout: transitionTimeout))
        assertExistsAfterScrolling(
            app.staticTexts["orders.detail.photos.reference.add.header"],
            in: app,
            timeout: transitionTimeout
        )
        assertExistsAfterScrolling(
            app.staticTexts["orders.detail.photos.item.photo-ui-fixture-reference"],
            in: app,
            timeout: transitionTimeout
        )
        assertExistsAfterScrolling(
            app.buttons["orders.detail.photos.reference.add"],
            in: app,
            timeout: transitionTimeout
        )
        assertExistsAfterScrolling(
            app.buttons["orders.detail.photos.reference.camera"],
            in: app,
            timeout: transitionTimeout
        )
        let referencePreview = app.buttons["orders.detail.photos.preview.photo-ui-fixture-reference"]
        assertExistsAfterScrolling(referencePreview, in: app, timeout: transitionTimeout)
        tapWhenReady(referencePreview, timeout: transitionTimeout)
        XCTAssertTrue(app.staticTexts["orders.detail.photos.preview.caption"].waitForExistence(timeout: transitionTimeout))
        XCTAssertTrue(app.staticTexts["orders.detail.photos.preview.caption"].label.contains("Customer sketch"))
        XCTAssertTrue(app.staticTexts["orders.detail.photos.preview.kind"].label.contains("Reference Photo"))
        tapWhenReady(app.buttons["orders.detail.photos.preview.editCaption"], timeout: transitionTimeout)
        XCTAssertTrue(app.navigationBars["Photo Caption"].waitForExistence(timeout: transitionTimeout))
        let captionField = app.textFields["orders.detail.photos.caption.text"]
        tapWhenReady(captionField, timeout: transitionTimeout)
        captionField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 30))
        captionField.typeText("Lace and pearls")
        tapWhenReady(app.buttons["orders.detail.photos.caption.save"], timeout: transitionTimeout)
        XCTAssertTrue(app.staticTexts["orders.detail.photos.preview.caption"].waitForExistence(timeout: transitionTimeout))
        XCTAssertTrue(app.staticTexts["orders.detail.photos.preview.caption"].label.contains("Lace and pearls"))
        tapWhenReady(app.buttons["orders.detail.photos.preview.close"], timeout: transitionTimeout)
        XCTAssertTrue(app.navigationBars["Photo Vanilla Birthday"].waitForExistence(timeout: transitionTimeout))
        XCTAssertTrue(app.staticTexts["orders.detail.photos.item.photo-ui-fixture-reference"].label.contains("Lace and pearls"))

        assertExistsAfterScrolling(
            app.staticTexts["orders.detail.photos.final.add.header"],
            in: app,
            timeout: transitionTimeout
        )
        assertExistsAfterScrolling(
            app.staticTexts["orders.detail.photos.item.photo-ui-fixture-final"],
            in: app,
            timeout: transitionTimeout
        )
        assertExistsAfterScrolling(
            app.buttons["orders.detail.photos.final.add"],
            in: app,
            timeout: transitionTimeout
        )
        assertExistsAfterScrolling(
            app.buttons["orders.detail.photos.final.camera"],
            in: app,
            timeout: transitionTimeout
        )
        let finalPreview = app.buttons["orders.detail.photos.preview.photo-ui-fixture-final"]
        assertExistsAfterScrolling(finalPreview, in: app, timeout: transitionTimeout)
        tapWhenReady(finalPreview, timeout: transitionTimeout)
        XCTAssertTrue(app.staticTexts["orders.detail.photos.preview.caption"].waitForExistence(timeout: transitionTimeout))
        XCTAssertTrue(app.staticTexts["orders.detail.photos.preview.caption"].label.contains("Finished cake"))
        tapWhenReady(app.buttons["orders.detail.photos.preview.promoteDesign"], timeout: transitionTimeout)
        XCTAssertTrue(app.navigationBars["Save Design"].waitForExistence(timeout: transitionTimeout))
        let designNameField = app.textFields["orders.detail.photos.design.name"]
        tapWhenReady(designNameField, timeout: transitionTimeout)
        designNameField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 30))
        designNameField.typeText("Pink Pearl Cake")
        tapWhenReady(app.buttons["orders.detail.photos.design.save"], timeout: transitionTimeout)
        XCTAssertTrue(app.navigationBars["Photo Vanilla Birthday"].waitForExistence(timeout: transitionTimeout))
        scrollToTop(in: app)
        assertExistsAfterScrolling(app.staticTexts["orders.detail.designName"], in: app, timeout: transitionTimeout)
        XCTAssertTrue(app.staticTexts["orders.detail.designName"].label.contains("Pink Pearl Cake"))
        XCTAssertTrue(app.staticTexts["orders.detail.designPhotoReference"].label.contains("photo-ui-fixture-final"))
    }

    func testOrderCanLinkCustomerFromSearchableSelection() throws {
        let app = makeApp()
        let transitionTimeout: TimeInterval = 15
        app.launch()

        tapWhenReady(app.staticTexts["Customers"])
        addCustomer(named: "Amy", phone: "5550101", in: app)
        app.navigationBars.buttons["CloudBake"].tap()

        tapWhenReady(app.staticTexts["Orders"], timeout: transitionTimeout)
        XCTAssertTrue(app.navigationBars["Orders"].waitForExistence(timeout: transitionTimeout))
        tapWhenReady(app.buttons["orders.add"], timeout: transitionTimeout)
        XCTAssertTrue(app.navigationBars["Add Order"].waitForExistence(timeout: transitionTimeout))

        tapWhenReady(app.buttons["orders.form.customerRecord"], timeout: transitionTimeout)
        XCTAssertTrue(app.navigationBars["Customer Record"].waitForExistence(timeout: transitionTimeout))
        tapWhenReady(
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "orders.customerSelection.customer."))
                .firstMatch,
            timeout: transitionTimeout
        )
        XCTAssertTrue(app.navigationBars["Add Order"].waitForExistence(timeout: transitionTimeout))

        typeText("Vanilla Birthday", into: app.textFields["orders.form.title"], timeout: transitionTimeout)
        typeText("Pink flowers", into: app.textFields["orders.form.cakeNotes"], timeout: transitionTimeout)
        dismissKeyboard(in: app)
        let saveButton = app.buttons["orders.form.save"]
        scrollToHittable(saveButton, in: app, timeout: transitionTimeout)
        tapWhenReady(saveButton, timeout: transitionTimeout)

        XCTAssertTrue(app.navigationBars["Orders"].waitForExistence(timeout: transitionTimeout))
        tapWhenReady(
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "orders.item."))
                .firstMatch,
            timeout: transitionTimeout
        )

        XCTAssertTrue(app.navigationBars["Vanilla Birthday"].waitForExistence(timeout: transitionTimeout))
        assertExistsAfterScrolling(app.staticTexts["orders.detail.customerName"], in: app, timeout: transitionTimeout)
        let allergyText = app.staticTexts["orders.detail.customerAllergies"]
        assertExistsAfterScrolling(allergyText, in: app, timeout: transitionTimeout)
        XCTAssertTrue(allergyText.label.contains("Nuts"))
    }

    func testOrderCanLinkRecipeFromSearchableSelection() throws {
        let app = makeApp()
        let transitionTimeout: TimeInterval = 25
        app.launch()

        tapWhenReady(app.staticTexts["Recipes"], timeout: transitionTimeout)
        addRecipe(named: "Vanilla Sponge", notes: "Birthday base", in: app)
        tapWhenReady(app.navigationBars.buttons["CloudBake"], timeout: transitionTimeout)

        tapWhenReady(app.staticTexts["Orders"], timeout: transitionTimeout)
        XCTAssertTrue(app.navigationBars["Orders"].waitForExistence(timeout: transitionTimeout))
        tapWhenReady(app.buttons["orders.add"], timeout: transitionTimeout)
        XCTAssertTrue(app.navigationBars["Add Order"].waitForExistence(timeout: transitionTimeout))

        typeText("Vanilla Birthday", into: app.textFields["orders.form.title"], timeout: transitionTimeout)
        dismissKeyboard(in: app)
        let customerNameField = app.textFields["orders.form.customerName"]
        scrollToHittable(customerNameField, in: app, timeout: transitionTimeout)
        typeText("Amy", into: customerNameField, timeout: transitionTimeout)
        dismissKeyboard(in: app)

        let recipeField = app.buttons["orders.form.recipe"]
        scrollToHittable(recipeField, in: app, timeout: transitionTimeout)
        tapWhenReady(recipeField, timeout: transitionTimeout)
        XCTAssertTrue(app.navigationBars["Recipe"].waitForExistence(timeout: transitionTimeout))
        tapWhenReady(
            app.buttons.matching(
                NSPredicate(
                    format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
                    "orders.recipeSelection.recipe.",
                    "Vanilla Sponge"
                )
            )
                .firstMatch,
            timeout: transitionTimeout
        )
        XCTAssertTrue(app.navigationBars["Add Order"].waitForExistence(timeout: transitionTimeout))

        tapWhenReady(app.buttons["orders.form.save"], timeout: transitionTimeout)

        XCTAssertTrue(app.navigationBars["Orders"].waitForExistence(timeout: transitionTimeout))
        let orderRow = app.buttons.matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
                "orders.item.",
                "Vanilla Birthday"
            )
        )
            .firstMatch
        scrollToHittable(orderRow, in: app, timeout: transitionTimeout)
        tapWhenReady(orderRow, timeout: transitionTimeout)

        XCTAssertTrue(app.navigationBars["Vanilla Birthday"].waitForExistence(timeout: transitionTimeout))
        let recipeName = app.staticTexts["orders.detail.recipeName"]
        assertExistsAfterScrolling(recipeName, in: app, timeout: transitionTimeout)
        XCTAssertTrue(recipeName.label.contains("Vanilla Sponge"))
    }

    func testOrderCanLinkDesignFromSearchableSelection() throws {
        let app = makeApp()
        let transitionTimeout: TimeInterval = 25
        app.launchEnvironment["CLOUDBAKE_SEED_CAKE_DESIGN_FIXTURE"] = "1"
        app.launch()

        tapWhenReady(app.staticTexts["Orders"], timeout: transitionTimeout)
        XCTAssertTrue(app.navigationBars["Orders"].waitForExistence(timeout: transitionTimeout))
        tapWhenReady(app.buttons["orders.add"], timeout: transitionTimeout)
        XCTAssertTrue(app.navigationBars["Add Order"].waitForExistence(timeout: transitionTimeout))

        typeText("Vanilla Birthday", into: app.textFields["orders.form.title"], timeout: transitionTimeout)
        typeText("Pink flowers", into: app.textFields["orders.form.cakeNotes"], timeout: transitionTimeout)
        dismissKeyboard(in: app)

        let customerNameField = app.textFields["orders.form.customerName"]
        scrollToHittable(customerNameField, in: app, timeout: transitionTimeout)
        typeText("Amy", into: customerNameField, timeout: transitionTimeout)
        dismissKeyboard(in: app)

        let designField = app.buttons["orders.form.design"]
        scrollToHittable(designField, in: app, timeout: transitionTimeout)
        tapWhenReady(designField, timeout: transitionTimeout)
        XCTAssertTrue(app.navigationBars["Design"].waitForExistence(timeout: transitionTimeout))
        tapWhenReady(
            app.buttons.matching(
                NSPredicate(
                    format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
                    "orders.designSelection.design.",
                    "Pink Floral Cake"
                )
            )
                .firstMatch,
            timeout: transitionTimeout
        )
        XCTAssertTrue(app.navigationBars["Add Order"].waitForExistence(timeout: transitionTimeout))

        tapWhenReady(app.buttons["orders.form.save"], timeout: transitionTimeout)

        XCTAssertTrue(app.navigationBars["Orders"].waitForExistence(timeout: transitionTimeout))
        let orderRow = app.buttons.matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
                "orders.item.",
                "Vanilla Birthday"
            )
        )
            .firstMatch
        scrollToHittable(orderRow, in: app, timeout: transitionTimeout)
        tapWhenReady(orderRow, timeout: transitionTimeout)

        XCTAssertTrue(app.navigationBars["Vanilla Birthday"].waitForExistence(timeout: transitionTimeout))
        let designName = app.staticTexts["orders.detail.designName"]
        assertExistsAfterScrolling(designName, in: app, timeout: transitionTimeout)
        XCTAssertTrue(designName.label.contains("Pink Floral Cake"))
        assertExistsAfterScrolling(app.staticTexts["orders.detail.designNotes"], in: app, timeout: transitionTimeout)
        assertExistsAfterScrolling(app.staticTexts["orders.detail.designPhotoReference"], in: app, timeout: transitionTimeout)
    }

    func testOrderCanUseLinkedRecipeToDeductInventory() throws {
        let app = makeApp()
        let transitionTimeout: TimeInterval = 15
        app.launch()

        tapWhenReady(app.staticTexts["Inventory"], timeout: transitionTimeout)
        addInventoryItem(named: "Cake flour", currentQuantity: "1000", minimumQuantity: "500", in: app)
        app.navigationBars.buttons["CloudBake"].tap()

        tapWhenReady(app.staticTexts["Recipes"], timeout: transitionTimeout)
        addRecipe(named: "Vanilla Sponge", notes: "Birthday base", in: app)
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "recipes.item."))
            .firstMatch
            .tap()
        XCTAssertTrue(app.navigationBars["Vanilla Sponge"].waitForExistence(timeout: transitionTimeout))
        app.buttons["recipes.ingredient.add"].tap()
        XCTAssertTrue(app.navigationBars["Add Ingredient"].waitForExistence(timeout: transitionTimeout))
        app.textFields["recipes.ingredient.quantity"].tap()
        app.textFields["recipes.ingredient.quantity"].typeText("250")
        app.buttons["recipes.ingredient.save"].tap()
        XCTAssertTrue(app.navigationBars["Vanilla Sponge"].waitForExistence(timeout: transitionTimeout))
        app.buttons["recipes.detail.done"].tap()
        app.navigationBars.buttons["CloudBake"].tap()

        tapWhenReady(app.staticTexts["Orders"], timeout: transitionTimeout)
        XCTAssertTrue(app.navigationBars["Orders"].waitForExistence(timeout: transitionTimeout))
        tapWhenReady(app.buttons["orders.add"], timeout: transitionTimeout)
        XCTAssertTrue(app.navigationBars["Add Order"].waitForExistence(timeout: transitionTimeout))
        typeText("Vanilla Birthday", into: app.textFields["orders.form.title"], timeout: transitionTimeout)
        dismissKeyboard(in: app)
        let customerNameField = app.textFields["orders.form.customerName"]
        scrollToHittable(customerNameField, in: app, timeout: transitionTimeout)
        typeText("Amy", into: customerNameField, timeout: transitionTimeout)
        dismissKeyboard(in: app)
        let recipeButton = app.buttons["orders.form.recipe"]
        scrollToHittable(recipeButton, in: app, timeout: transitionTimeout)
        tapWhenReady(recipeButton, timeout: transitionTimeout)
        XCTAssertTrue(app.navigationBars["Recipe"].waitForExistence(timeout: transitionTimeout))
        tapWhenReady(
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "orders.recipeSelection.recipe."))
                .firstMatch,
            timeout: transitionTimeout
        )
        XCTAssertTrue(app.navigationBars["Add Order"].waitForExistence(timeout: transitionTimeout))
        let recipeMultiplierField = app.textFields["orders.form.recipeScaleMultiplier"]
        scrollToHittable(recipeMultiplierField, in: app, timeout: transitionTimeout)
        tapWhenReady(recipeMultiplierField, timeout: transitionTimeout)
        recipeMultiplierField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 10))
        recipeMultiplierField.typeText("2")
        let saveButton = app.buttons["orders.form.save"]
        scrollToHittable(saveButton, in: app, timeout: transitionTimeout)
        tapWhenReady(saveButton, timeout: transitionTimeout)

        XCTAssertTrue(app.navigationBars["Orders"].waitForExistence(timeout: transitionTimeout))
        tapWhenReady(
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "orders.item."))
                .firstMatch,
            timeout: transitionTimeout
        )
        XCTAssertTrue(app.navigationBars["Vanilla Birthday"].waitForExistence(timeout: transitionTimeout))
        assertExistsAfterScrolling(app.buttons["orders.detail.statusMenu"], in: app, timeout: transitionTimeout)
        tapWhenReady(app.buttons["orders.detail.statusMenu"], timeout: transitionTimeout)
        tapExisting(app.buttons["Confirmed"], timeout: transitionTimeout)
        let confirmedStatus = app.staticTexts["orders.detail.status"]
        XCTAssertTrue(confirmedStatus.waitForExistence(timeout: transitionTimeout))
        XCTAssertTrue(confirmedStatus.label.contains("Confirmed"))
        tapWhenReady(app.buttons["orders.detail.statusMenu"], timeout: transitionTimeout)
        tapExisting(app.buttons["Ready"], timeout: transitionTimeout)
        tapExisting(app.buttons["orders.detail.confirmInventoryDeduction"], timeout: transitionTimeout)
        let readyStatus = app.staticTexts["orders.detail.status"]
        XCTAssertTrue(readyStatus.waitForExistence(timeout: transitionTimeout))
        XCTAssertTrue(readyStatus.label.contains("Ready"))
        app.buttons["orders.detail.done"].tap()
        app.navigationBars.buttons["CloudBake"].tap()

        tapWhenReady(app.staticTexts["Inventory"], timeout: transitionTimeout)
        XCTAssertTrue(app.staticTexts["Current Quantity: 500 g"].waitForExistence(timeout: transitionTimeout))
    }

    func testOrderCalendarViewShowsOrders() throws {
        let app = makeApp()
        let transitionTimeout: TimeInterval = 15
        app.launch()

        tapWhenReady(app.staticTexts["Orders"])
        XCTAssertTrue(app.navigationBars["Orders"].waitForExistence(timeout: transitionTimeout))
        addOrder(named: "Vanilla Birthday", notes: "Pink flowers", customerName: "Amy", in: app)

        XCTAssertTrue(app.staticTexts["Vanilla Birthday"].waitForExistence(timeout: transitionTimeout))
        XCTAssertTrue(app.staticTexts["Amy"].waitForExistence(timeout: transitionTimeout))
        let orderRow = app.buttons.matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
                "orders.item.",
                "Vanilla Birthday"
            )
        )
            .firstMatch
        assertExistsAfterScrolling(orderRow, in: app, timeout: transitionTimeout)
        tapWhenReady(orderRow, timeout: transitionTimeout)
        XCTAssertTrue(app.navigationBars["Vanilla Birthday"].waitForExistence(timeout: transitionTimeout))
    }

    func testCompletedOrderMovesToCompletedTab() throws {
        let app = makeApp()
        let transitionTimeout: TimeInterval = 15
        app.launch()

        tapWhenReady(app.staticTexts["Orders"], timeout: transitionTimeout)
        XCTAssertTrue(app.navigationBars["Orders"].waitForExistence(timeout: transitionTimeout))
        addOrder(named: "Completed Birthday", notes: "Boxed", customerName: "Amy", in: app)

        let activeOrderRow = app.buttons.matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
                "orders.item.",
                "Completed Birthday"
            )
        )
            .firstMatch
        assertExistsAfterScrolling(activeOrderRow, in: app, timeout: transitionTimeout)
        tapWhenReady(activeOrderRow, timeout: transitionTimeout)

        XCTAssertTrue(app.navigationBars["Completed Birthday"].waitForExistence(timeout: transitionTimeout))
        tapWhenReady(app.buttons["orders.detail.statusMenu"], timeout: transitionTimeout)
        tapExisting(app.buttons["Completed"], timeout: transitionTimeout)
        let completedStatus = app.staticTexts["orders.detail.status"]
        XCTAssertTrue(completedStatus.waitForExistence(timeout: transitionTimeout))
        XCTAssertTrue(completedStatus.label.contains("Completed"))
        app.buttons["orders.detail.done"].tap()

        XCTAssertTrue(app.navigationBars["Orders"].waitForExistence(timeout: transitionTimeout))
        tapWhenReady(app.buttons["Completed"], timeout: transitionTimeout)
        let completedOrderRow = app.buttons.matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
                "orders.item.",
                "Completed Birthday"
            )
        )
            .firstMatch
        assertExistsAfterScrolling(completedOrderRow, in: app, timeout: transitionTimeout)
    }

    func testCancelledOrderAppearsInCompletedTabWithBadge() throws {
        let app = makeApp()
        let transitionTimeout: TimeInterval = 15
        app.launch()

        tapWhenReady(app.staticTexts["Orders"], timeout: transitionTimeout)
        XCTAssertTrue(app.navigationBars["Orders"].waitForExistence(timeout: transitionTimeout))
        addOrder(named: "Cancelled Birthday", notes: "Customer changed date", customerName: "Amy", in: app)

        let activeOrderRow = app.buttons.matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
                "orders.item.",
                "Cancelled Birthday"
            )
        )
            .firstMatch
        assertExistsAfterScrolling(activeOrderRow, in: app, timeout: transitionTimeout)
        tapWhenReady(activeOrderRow, timeout: transitionTimeout)

        XCTAssertTrue(app.navigationBars["Cancelled Birthday"].waitForExistence(timeout: transitionTimeout))
        tapWhenReady(app.buttons["orders.detail.statusMenu"], timeout: transitionTimeout)
        tapExisting(app.buttons["Cancelled"], timeout: transitionTimeout)
        let cancelledStatus = app.staticTexts["orders.detail.status"]
        XCTAssertTrue(cancelledStatus.waitForExistence(timeout: transitionTimeout))
        XCTAssertTrue(cancelledStatus.label.contains("Cancelled"))
        app.buttons["orders.detail.done"].tap()

        XCTAssertTrue(app.navigationBars["Orders"].waitForExistence(timeout: transitionTimeout))
        tapWhenReady(app.buttons["Completed"], timeout: transitionTimeout)
        let cancelledOrderRow = app.buttons.matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
                "orders.item.",
                "Cancelled Birthday"
            )
        )
            .firstMatch
        assertExistsAfterScrolling(cancelledOrderRow, in: app, timeout: transitionTimeout)
        XCTAssertTrue(
            app.images.matching(NSPredicate(format: "identifier BEGINSWITH %@", "orders.item.cancelledBadge."))
                .firstMatch
                .waitForExistence(timeout: transitionTimeout)
        )
    }

    func testOrderDetailUsesSplitViewOnIPad() throws {
        let app = makeApp()
        let transitionTimeout: TimeInterval = 15
        app.launch()

        guard app.windows.firstMatch.waitForExistence(timeout: 5),
              app.windows.firstMatch.frame.width >= 700 else {
            throw XCTSkip("Order split view is only expected on regular-width iPad layouts.")
        }

        tapWhenReady(app.staticTexts["Orders"], timeout: transitionTimeout)
        XCTAssertTrue(app.navigationBars["Orders"].waitForExistence(timeout: transitionTimeout))
        XCTAssertTrue(app.staticTexts["Select an order"].waitForExistence(timeout: transitionTimeout))

        addOrder(named: "Vanilla Birthday", notes: "Pink flowers", customerName: "Amy", in: app)
        tapWhenReady(
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "orders.item."))
                .firstMatch,
            timeout: transitionTimeout
        )

        XCTAssertTrue(app.navigationBars["Vanilla Birthday"].waitForExistence(timeout: transitionTimeout))
        XCTAssertFalse(app.buttons["orders.detail.done"].exists)
        XCTAssertTrue(app.staticTexts["orders.detail.cake"].waitForExistence(timeout: transitionTimeout))
        XCTAssertTrue(app.staticTexts["orders.detail.customerName"].waitForExistence(timeout: transitionTimeout))
        XCTAssertTrue(app.staticTexts["orders.detail.fulfillmentType"].waitForExistence(timeout: transitionTimeout))
    }

    func testRecipesCanBeAdded() throws {
        let app = makeApp()
        app.launch()

        app.staticTexts["Recipes"].tap()
        XCTAssertTrue(app.navigationBars["Recipes"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["No recipes yet"].waitForExistence(timeout: 5))

        app.buttons["recipes.add"].tap()
        XCTAssertTrue(app.navigationBars["Add Recipe"].waitForExistence(timeout: 5))
        app.textFields["recipes.form.name"].tap()
        app.textFields["recipes.form.name"].typeText("Vanilla Sponge")
        app.textFields["recipes.form.notes"].tap()
        app.textFields["recipes.form.notes"].typeText("Book page 12")
        app.buttons["recipes.form.save"].tap()

        XCTAssertTrue(app.navigationBars["Recipes"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Vanilla Sponge"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Book page 12"].waitForExistence(timeout: 5))
    }

    func testRecipeCanBeImportedFromRecognizedTextDraft() throws {
        let app = makeApp()
        app.launch()

        app.staticTexts["Inventory"].tap()
        addInventoryItem(named: "Flour", currentQuantity: "1000", minimumQuantity: "500", in: app)
        app.navigationBars.buttons["CloudBake"].tap()

        app.staticTexts["Recipes"].tap()
        XCTAssertTrue(app.navigationBars["Recipes"].waitForExistence(timeout: 5))
        app.buttons["recipes.import"].tap()
        XCTAssertTrue(app.navigationBars["Import Recipe"].waitForExistence(timeout: 5))

        let recipeText = app.textFields["recipes.import.text"]
        XCTAssertTrue(recipeText.waitForExistence(timeout: 5))
        recipeText.tap()
        recipeText.typeText("Chocolate Fudge\nFlour 250 g\nBake until set")
        app.buttons["recipes.import.createDraft"].tap()

        XCTAssertEqual(app.textFields["recipes.import.name"].value as? String, "Chocolate Fudge")
        XCTAssertEqual(app.textFields["recipes.import.notes"].value as? String, "Bake until set")
        XCTAssertTrue(app.textFields.matching(NSPredicate(format: "identifier BEGINSWITH %@", "recipes.import.ingredient.name.")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Flour"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields.matching(NSPredicate(format: "identifier BEGINSWITH %@", "recipes.import.ingredient.quantity.")).firstMatch.waitForExistence(timeout: 5))
        app.buttons["recipes.import.save"].tap()

        XCTAssertTrue(app.navigationBars["Recipes"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Chocolate Fudge"].waitForExistence(timeout: 5))
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "recipes.item."))
            .firstMatch
            .tap()
        XCTAssertTrue(app.navigationBars["Chocolate Fudge"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Flour"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["250 g"].waitForExistence(timeout: 5))
    }

    func testRecipeIngredientCanBeAddedFromInventory() throws {
        let app = makeApp()
        app.launch()

        app.staticTexts["Inventory"].tap()
        addInventoryItem(named: "Cake flour", currentQuantity: "1000", minimumQuantity: "500", in: app)
        app.navigationBars.buttons["CloudBake"].tap()

        app.staticTexts["Recipes"].tap()
        addRecipe(named: "Vanilla Sponge", notes: "Book page 12", in: app)
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "recipes.item."))
            .firstMatch
            .tap()
        XCTAssertTrue(app.navigationBars["Vanilla Sponge"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["No ingredients yet"].waitForExistence(timeout: 5))

        app.buttons["recipes.ingredient.add"].tap()
        XCTAssertTrue(app.navigationBars["Add Ingredient"].waitForExistence(timeout: 5))
        app.textFields["recipes.ingredient.quantity"].tap()
        app.textFields["recipes.ingredient.quantity"].typeText("250")
        app.textFields["recipes.ingredient.note"].tap()
        app.textFields["recipes.ingredient.note"].typeText("Sift")
        app.buttons["recipes.ingredient.save"].tap()

        XCTAssertTrue(app.navigationBars["Vanilla Sponge"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Cake flour"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["250 g"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Sift"].waitForExistence(timeout: 5))
    }

    func testRecipeNotesCanBeEditedFromDetail() throws {
        let app = makeApp()
        app.launch()

        app.staticTexts["Recipes"].tap()
        addRecipe(named: "Vanilla Sponge", notes: "Book page 12", in: app)
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "recipes.item."))
            .firstMatch
            .tap()
        XCTAssertTrue(app.navigationBars["Vanilla Sponge"].waitForExistence(timeout: 5))

        app.buttons["recipes.detail.edit"].tap()
        XCTAssertTrue(app.navigationBars["Edit Recipe"].waitForExistence(timeout: 5))
        let notesField = app.textFields["recipes.form.notes"]
        XCTAssertTrue(notesField.waitForExistence(timeout: 5))
        notesField.tap()
        notesField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 20))
        notesField.typeText("Use two tins")
        app.buttons["recipes.form.save"].tap()

        XCTAssertTrue(app.navigationBars["Vanilla Sponge"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Use two tins")).firstMatch.waitForExistence(timeout: 5))
    }

    func testCustomerCanBeAddedAndViewed() throws {
        let app = makeApp()
        app.launch()

        app.staticTexts["Customers"].tap()
        XCTAssertTrue(app.navigationBars["Customers"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["No customers yet"].waitForExistence(timeout: 5))

        addCustomer(named: "Amy", phone: "5550101", in: app)

        XCTAssertTrue(app.navigationBars["Customers"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Amy"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["5550101"].waitForExistence(timeout: 5))
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "customers.item."))
            .firstMatch
            .tap()

        XCTAssertTrue(app.navigationBars["Amy"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Name"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Phone"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Birthday"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Nuts"].waitForExistence(timeout: 5))
    }

    func testCustomerDetailUsesSplitViewOnIPad() throws {
        let app = makeApp()
        app.launchEnvironment["CLOUDBAKE_SEED_CUSTOMER_FIXTURE"] = "1"
        app.launch()

        guard app.windows.firstMatch.waitForExistence(timeout: 5),
              app.windows.firstMatch.frame.width >= 700 else {
            throw XCTSkip("Customer split view is only expected on regular-width iPad layouts.")
        }

        app.staticTexts["Customers"].tap()
        XCTAssertTrue(app.navigationBars["Customers"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Select a customer"].waitForExistence(timeout: 5))

        XCTAssertTrue(app.staticTexts["Amy"].waitForExistence(timeout: 5))
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "customers.item."))
            .firstMatch
            .tap()

        XCTAssertTrue(app.navigationBars["Amy"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["customers.detail.done"].exists)
        XCTAssertTrue(app.staticTexts["Name"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Phone"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Birthday"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Nuts"].waitForExistence(timeout: 5))
    }

    func testCustomerAddOffersContactsImportAndManualEntry() throws {
        let app = makeApp()
        let transitionTimeout: TimeInterval = 15
        app.launch()

        tapWhenReady(app.staticTexts["Customers"], timeout: transitionTimeout)
        XCTAssertTrue(app.navigationBars["Customers"].waitForExistence(timeout: transitionTimeout))
        tapWhenReady(app.buttons["customers.add"], timeout: transitionTimeout)

        XCTAssertTrue(app.buttons["Import From Contacts"].waitForExistence(timeout: transitionTimeout))
        tapWhenReady(app.buttons["Enter Manually"], timeout: transitionTimeout)
        XCTAssertTrue(app.navigationBars["Add Customer"].waitForExistence(timeout: transitionTimeout))
    }

    func testCustomerDuplicateWarningAppearsBeforeSaving() throws {
        let app = makeApp()
        let transitionTimeout: TimeInterval = 15
        app.launch()

        tapWhenReady(app.staticTexts["Customers"], timeout: transitionTimeout)
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
        let app = makeApp()
        app.launch()

        app.staticTexts["Customers"].tap()
        addCustomer(named: "Amy", phone: "5550101", in: app)
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "customers.item."))
            .firstMatch
            .tap()
        XCTAssertTrue(app.navigationBars["Amy"].waitForExistence(timeout: 5))

        app.buttons["customers.detail.edit"].tap()
        XCTAssertTrue(app.navigationBars["Edit Customer"].waitForExistence(timeout: 5))
        let nameField = app.textFields["customers.form.name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 3))
        nameField.typeText("Amy B")
        app.buttons["customers.form.save"].tap()

        XCTAssertTrue(app.navigationBars["Amy B"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Amy B"].waitForExistence(timeout: 5))
    }

}
