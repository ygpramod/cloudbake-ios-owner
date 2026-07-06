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
        tapWhenReady(app.buttons["orders.form.save"], timeout: transitionTimeout)

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

        scrollToTop(in: app)
        let titleField = app.textFields["orders.form.title"]
        scrollToHittable(titleField, in: app, timeout: transitionTimeout)
        typeText("Vanilla Birthday", into: titleField, timeout: transitionTimeout)

        let customerNameField = app.textFields["orders.form.customerName"]
        scrollToHittable(customerNameField, in: app, timeout: transitionTimeout)
        typeText("Amy", into: customerNameField, timeout: transitionTimeout)
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

        scrollToTop(in: app)
        let titleField = app.textFields["orders.form.title"]
        scrollToHittable(titleField, in: app, timeout: transitionTimeout)
        typeText("Vanilla Birthday", into: titleField, timeout: transitionTimeout)
        typeText("Pink flowers", into: app.textFields["orders.form.cakeNotes"], timeout: transitionTimeout)

        let customerNameField = app.textFields["orders.form.customerName"]
        scrollToHittable(customerNameField, in: app, timeout: transitionTimeout)
        typeText("Amy", into: customerNameField, timeout: transitionTimeout)
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
        app.swipeUp()
        tapWhenReady(app.buttons["orders.form.recipe"], timeout: transitionTimeout)
        XCTAssertTrue(app.navigationBars["Recipe"].waitForExistence(timeout: transitionTimeout))
        tapWhenReady(
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "orders.recipeSelection.recipe."))
                .firstMatch,
            timeout: transitionTimeout
        )
        XCTAssertTrue(app.navigationBars["Add Order"].waitForExistence(timeout: transitionTimeout))
        scrollToTop(in: app)
        typeText("Vanilla Birthday", into: app.textFields["orders.form.title"], timeout: transitionTimeout)
        let customerNameField = app.textFields["orders.form.customerName"]
        scrollToHittable(customerNameField, in: app, timeout: transitionTimeout)
        typeText("Amy", into: customerNameField, timeout: transitionTimeout)
        tapWhenReady(app.buttons["orders.form.save"], timeout: transitionTimeout)

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
        XCTAssertTrue(app.staticTexts["Current Quantity: 750 g"].waitForExistence(timeout: transitionTimeout))
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

    func testInventoryDuplicateNameShowsWarningBeforeAdding() throws {
        let app = makeApp()
        app.launch()

        app.staticTexts["Inventory"].tap()
        addInventoryItem(named: "Cake flour", currentQuantity: "250", minimumQuantity: "500", in: app)
        app.buttons["inventory.add"].tap()
        XCTAssertTrue(app.navigationBars["Add Item"].waitForExistence(timeout: 5))

        app.textFields["inventory.form.name"].tap()
        app.textFields["inventory.form.name"].typeText("cake flours")
        app.textFields["inventory.form.currentQuantity"].tap()
        app.textFields["inventory.form.currentQuantity"].typeText("100")
        app.textFields["inventory.form.minimumQuantity"].tap()
        app.textFields["inventory.form.minimumQuantity"].typeText("250")
        app.buttons["inventory.form.save"].tap()

        XCTAssertTrue(app.staticTexts["Possible duplicate: Cake flour already exists. Tap Save again to add a separate item."].waitForExistence(timeout: 5))
    }

    func testInventoryOwnerJourneyShowsDetailEditsStockHistoryAndDashboard() throws {
        let app = makeApp()
        app.launch()

        app.staticTexts["Inventory"].tap()
        addInventoryItem(named: "Cake flour", currentQuantity: "250", minimumQuantity: "500", in: app)

        XCTAssertTrue(app.staticTexts["Cake flour"].waitForExistence(timeout: 5))
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "inventory.item.view."))
            .firstMatch
            .coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5))
            .tap()
        XCTAssertTrue(app.navigationBars["Inventory Item"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Name"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Unit"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Current Quantity"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Minimum Quantity"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Expiry"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Quantity"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["250 g"].waitForExistence(timeout: 5))

        let batchRow = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "inventory.detail.batch.edit.")).firstMatch
        XCTAssertTrue(batchRow.waitForExistence(timeout: 5))
        batchRow.tap()
        XCTAssertTrue(app.navigationBars["Edit Batch"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["inventory.batch.quantity"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.datePickers["inventory.batch.expiryDate"].waitForExistence(timeout: 5))
        app.buttons["inventory.batch.save"].tap()
        XCTAssertTrue(app.navigationBars["Inventory Item"].waitForExistence(timeout: 5))

        app.buttons["inventory.detail.edit"].tap()
        XCTAssertTrue(app.navigationBars["Edit Item"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Name"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Minimum Quantity"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["inventory.form.currentQuantity"].exists)
        XCTAssertFalse(app.buttons["inventory.form.unit"].exists)

        let minimumQuantityField = app.textFields["inventory.form.minimumQuantity"]
        minimumQuantityField.tap()
        minimumQuantityField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 3))
        minimumQuantityField.typeText("600")
        app.buttons["inventory.form.save"].tap()

        XCTAssertTrue(app.navigationBars["Inventory Item"].waitForExistence(timeout: 5))
        app.buttons["inventory.detail.done"].tap()
        XCTAssertTrue(app.staticTexts["Minimum Quantity: 600 g"].waitForExistence(timeout: 5))

        adjustFirstInventoryItem(by: "100", in: app)
        XCTAssertTrue(app.staticTexts["Current Quantity: 350 g"].waitForExistence(timeout: 5))

        consumeFirstInventoryItem(by: "50", in: app)
        XCTAssertTrue(app.staticTexts["Current Quantity: 300 g"].waitForExistence(timeout: 5))

        let row = firstEditableInventoryRow(in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.swipeRight()
        app.buttons["History"].tap()

        XCTAssertTrue(app.navigationBars["Stock History"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Cake flour"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Used"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["-50 g"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Adjustment"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["+100 g"].waitForExistence(timeout: 5))
        app.buttons["inventory.history.done"].tap()
        app.navigationBars.buttons["CloudBake"].tap()

        XCTAssertTrue(app.navigationBars["CloudBake"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Low inventory"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Cake flour"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Expiring soon"].waitForExistence(timeout: 5))
    }

    func testInventoryCanBeArchivedAndRestored() throws {
        let app = makeApp()
        let transitionTimeout: TimeInterval = 20
        app.launch()

        tapWhenReady(app.staticTexts["Inventory"], timeout: transitionTimeout)
        addInventoryItem(named: "Cake flour", currentQuantity: "250", minimumQuantity: "500", in: app)

        let row = inventoryRow(named: "Cake flour", in: app)
        scrollToHittable(row, in: app, timeout: transitionTimeout)
        row.swipeLeft()
        tapWhenReady(
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "inventory.item.archive.")).firstMatch,
            timeout: transitionTimeout
        )
        XCTAssertTrue(app.staticTexts["No inventory yet"].waitForExistence(timeout: transitionTimeout))

        tapWhenReady(app.buttons["inventory.archived"], timeout: transitionTimeout)
        XCTAssertTrue(app.navigationBars["Archived"].waitForExistence(timeout: transitionTimeout))

        let archivedRow = archivedInventoryRow(named: "Cake flour", in: app)
        scrollToHittable(archivedRow, in: app, timeout: transitionTimeout)
        archivedRow.swipeLeft()
        tapWhenReady(
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "inventory.archived.restore.")).firstMatch,
            timeout: transitionTimeout
        )
        XCTAssertTrue(app.staticTexts["No archived inventory"].waitForExistence(timeout: transitionTimeout))
        tapWhenReady(app.buttons["inventory.archived.done"], timeout: transitionTimeout)

        XCTAssertTrue(app.staticTexts["Cake flour"].waitForExistence(timeout: transitionTimeout))
        XCTAssertTrue(app.staticTexts["Current Quantity: 250 g"].waitForExistence(timeout: transitionTimeout))
    }

    func testInventoryDetailShowsStockActionsInMoreMenu() throws {
        let app = makeApp()
        app.launch()

        app.staticTexts["Inventory"].tap()
        addInventoryItem(named: "Cake flour", currentQuantity: "250", minimumQuantity: "500", in: app)
        firstEditableInventoryRow(in: app).tap()
        XCTAssertTrue(app.navigationBars["Inventory Item"].waitForExistence(timeout: 5))

        XCTAssertTrue(app.buttons["inventory.detail.edit"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["inventory.detail.more"].waitForExistence(timeout: 5))

        app.buttons["inventory.detail.more"].tap()
        app.buttons["inventory.detail.adjust"].tap()
        XCTAssertTrue(app.navigationBars["Adjust Stock"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Inventory Item"].waitForExistence(timeout: 5))

        app.buttons["inventory.detail.more"].tap()
        app.buttons["inventory.detail.consume"].tap()
        XCTAssertTrue(app.navigationBars["Use Stock"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Inventory Item"].waitForExistence(timeout: 5))

        app.buttons["inventory.detail.more"].tap()
        app.buttons["inventory.detail.history"].tap()
        XCTAssertTrue(app.navigationBars["Stock History"].waitForExistence(timeout: 5))
        app.buttons["inventory.history.done"].tap()
        XCTAssertTrue(app.navigationBars["Inventory Item"].waitForExistence(timeout: 5))
    }

    func testInventoryPurchaseBillImportShowsCameraAndManualDraftControls() throws {
        let app = makeApp()
        app.launch()

        app.staticTexts["Inventory"].tap()
        app.buttons["inventory.purchaseBill.import"].tap()
        XCTAssertTrue(app.navigationBars["Import Bill"].waitForExistence(timeout: 5))

        XCTAssertTrue(app.buttons["inventory.purchaseBill.camera"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["inventory.purchaseBill.library"].waitForExistence(timeout: 5))
        let billText = app.textFields["inventory.purchaseBill.text"]
        XCTAssertTrue(billText.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["inventory.purchaseBill.createDrafts"].waitForExistence(timeout: 5))
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
        app.launch()

        app.staticTexts["Customers"].tap()
        addCustomer(named: "Amy", phone: "5550101", in: app)
        app.buttons["customers.add"].tap()
        XCTAssertTrue(app.buttons["Enter Manually"].waitForExistence(timeout: 5))
        app.buttons["Enter Manually"].tap()
        XCTAssertTrue(app.navigationBars["Add Customer"].waitForExistence(timeout: 5))
        app.textFields["customers.form.name"].tap()
        app.textFields["customers.form.name"].typeText("Amy")
        app.textFields["customers.form.phone"].tap()
        app.textFields["customers.form.phone"].typeText("5550101")
        app.buttons["customers.form.save"].tap()

        XCTAssertTrue(app.staticTexts["Possible duplicate: Amy already exists. Tap Save again to add a separate customer."].waitForExistence(timeout: 5))
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

    private func makeApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["CLOUDBAKE_USE_IN_MEMORY_DATABASE"] = "1"
        return app
    }

    private func addInventoryItem(
        named name: String,
        currentQuantity: String,
        minimumQuantity: String,
        in app: XCUIApplication
    ) {
        app.buttons["inventory.add"].tap()
        XCTAssertTrue(app.navigationBars["Add Item"].waitForExistence(timeout: 5))
        app.textFields["inventory.form.name"].tap()
        app.textFields["inventory.form.name"].typeText(name)
        app.textFields["inventory.form.currentQuantity"].tap()
        app.textFields["inventory.form.currentQuantity"].typeText(currentQuantity)
        app.textFields["inventory.form.minimumQuantity"].tap()
        app.textFields["inventory.form.minimumQuantity"].typeText(minimumQuantity)
        app.buttons["inventory.form.save"].tap()
    }

    private func addOrder(
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

    private func addRecipe(named name: String, notes: String, in app: XCUIApplication) {
        app.buttons["recipes.add"].tap()
        XCTAssertTrue(app.navigationBars["Add Recipe"].waitForExistence(timeout: 5))
        app.textFields["recipes.form.name"].tap()
        app.textFields["recipes.form.name"].typeText(name)
        app.textFields["recipes.form.notes"].tap()
        app.textFields["recipes.form.notes"].typeText(notes)
        app.buttons["recipes.form.save"].tap()
        XCTAssertTrue(app.navigationBars["Recipes"].waitForExistence(timeout: 5))
    }

    private func addCustomer(named name: String, phone: String, in app: XCUIApplication) {
        app.buttons["customers.add"].tap()
        XCTAssertTrue(app.buttons["Enter Manually"].waitForExistence(timeout: 5))
        app.buttons["Enter Manually"].tap()
        XCTAssertTrue(app.navigationBars["Add Customer"].waitForExistence(timeout: 5))
        app.textFields["customers.form.name"].tap()
        app.textFields["customers.form.name"].typeText(name)
        app.textFields["customers.form.phone"].tap()
        app.textFields["customers.form.phone"].typeText(phone)
        app.textFields["customers.form.email"].tap()
        app.textFields["customers.form.email"].typeText("amy@example.com")
        app.textFields["customers.form.address"].tap()
        app.textFields["customers.form.address"].typeText("10 Cake Street")
        app.textFields["customers.form.importantDate.label"].tap()
        app.textFields["customers.form.importantDate.label"].typeText("Birthday")
        app.textFields["customers.form.allergies"].tap()
        app.textFields["customers.form.allergies"].typeText("Nuts")
        app.buttons["customers.form.save"].tap()
    }

    private func adjustFirstInventoryItem(by quantity: String, in app: XCUIApplication) {
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

    private func consumeFirstInventoryItem(by quantity: String, in app: XCUIApplication) {
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

    private func firstEditableInventoryRow(in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "inventory.item.view.")).firstMatch
    }

    private func inventoryRow(named name: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
                "inventory.item.view.",
                name
            )
        )
        .firstMatch
    }

    private func archivedInventoryRow(named name: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
                "inventory.archived.item.",
                name
            )
        )
        .firstMatch
    }

    private func tapWhenReady(
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

    private func tapExisting(
        _ element: XCUIElement,
        timeout: TimeInterval = 10,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let target = element.firstMatch
        XCTAssertTrue(target.waitForExistence(timeout: timeout), "Element did not exist before tap.", file: file, line: line)
        target.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    private func typeText(
        _ text: String,
        into element: XCUIElement,
        timeout: TimeInterval = 10,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        tapWhenReady(element, timeout: timeout, file: file, line: line)
        element.typeText(text)
    }

    private func assertExistsAfterScrolling(
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

    private func scrollToHittable(
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

    private func scrollToTop(in app: XCUIApplication) {
        for _ in 0..<3 {
            app.swipeDown()
        }
    }
}
