import XCTest

extension CloudBakeOwnerUITests {
    func testOrderAddLongPressCanCreateABlankTemplate() throws {
        let app = makeApp()
        let transitionTimeout: TimeInterval = 15
        app.launch()

        openDashboardDestination("Orders", in: app)
        let addOrder = app.buttons["orders.add"]
        XCTAssertTrue(addOrder.waitForExistence(timeout: transitionTimeout))
        addOrder.press(forDuration: 1)

        let createTemplate = app.buttons["Create Template"]
        XCTAssertTrue(createTemplate.waitForExistence(timeout: transitionTimeout))
        tapWhenReady(createTemplate, timeout: transitionTimeout)
        let blankTemplate = nativeDialogAction(labeled: "Blank Template", in: app)
        XCTAssertTrue(blankTemplate.waitForExistence(timeout: transitionTimeout))
        XCTAssertTrue(nativeDialogAction(labeled: "Existing Order", in: app).exists)
        XCTAssertTrue(nativeDialogAction(labeled: "Another Template", in: app).exists)
        tapWhenReady(blankTemplate, timeout: transitionTimeout)

        XCTAssertTrue(app.navigationBars["New Template"].waitForExistence(timeout: transitionTimeout))
        let templateName = app.textFields["orders.template.form.name"]
        typeText("Quick Custom Template", into: templateName, timeout: transitionTimeout)
        dismissKeyboard(in: app)
        tapWhenReady(app.buttons["orders.form.save"], timeout: transitionTimeout)

        assertScreenVisible("screen.orders", in: app, timeout: transitionTimeout)
        XCTAssertTrue(app.staticTexts["No orders yet"].exists)
        tapWhenReady(app.buttons["orders.add"], timeout: transitionTimeout)
        tapWhenReady(app.buttons["orders.form.template.choose"], timeout: transitionTimeout)
        XCTAssertTrue(
            app.buttons.matching(
                NSPredicate(format: "label CONTAINS %@", "Quick Custom Template")
            ).firstMatch.waitForExistence(timeout: transitionTimeout)
        )
    }

    func testOrderAddLongPressCanStartFromOrderOrTemplate() throws {
        let app = makeApp()
        let transitionTimeout: TimeInterval = 15
        app.launchEnvironment["CLOUDBAKE_SEED_ORDER_CUSTOMER_LINK_FIXTURE"] = "1"
        app.launch()

        openDashboardDestination("Orders", in: app)
        openTemplateSource("Existing Order", in: app, timeout: transitionTimeout)
        XCTAssertTrue(app.navigationBars["Choose Order"].waitForExistence(timeout: transitionTimeout))
        tapWhenReady(
            app.buttons["orders.template.source.order.order-ui-fixture-customer-link"],
            timeout: transitionTimeout
        )
        XCTAssertTrue(app.navigationBars["New Template"].waitForExistence(timeout: transitionTimeout))
        XCTAssertEqual(
            app.textFields["orders.template.form.name"].value as? String,
            "Vanilla Birthday Template"
        )
        XCTAssertEqual(app.textFields["orders.form.title"].value as? String, "Vanilla Birthday")
        tapWhenReady(app.buttons["orders.form.cancel"], timeout: transitionTimeout)

        assertScreenVisible("screen.orders", in: app, timeout: transitionTimeout)
        openTemplateSource("Another Template", in: app, timeout: transitionTimeout)
        XCTAssertTrue(app.navigationBars["Choose Template"].waitForExistence(timeout: transitionTimeout))
        tapWhenReady(
            app.buttons["orders.template.source.template.starter-template-two-tier-wedding"],
            timeout: transitionTimeout
        )
        XCTAssertTrue(app.navigationBars["New Template"].waitForExistence(timeout: transitionTimeout))
        XCTAssertEqual(
            app.textFields["orders.template.form.name"].value as? String,
            "Two-Tier Wedding Cake Copy"
        )
        XCTAssertEqual(
            app.textFields["orders.form.title"].value as? String,
            "Two-Tier Wedding Cake"
        )
    }

    private func openTemplateSource(
        _ source: String,
        in app: XCUIApplication,
        timeout: TimeInterval
    ) {
        let addOrder = app.buttons["orders.add"]
        XCTAssertTrue(addOrder.waitForExistence(timeout: timeout))
        addOrder.press(forDuration: 1)
        tapWhenReady(app.buttons["Create Template"], timeout: timeout)
        tapWhenReady(nativeDialogAction(labeled: source, in: app), timeout: timeout)
    }

    func testStarterOrderTemplateCanBeAppliedOnFirstUse() throws {
        let app = makeApp()
        let transitionTimeout: TimeInterval = 15
        app.launch()

        openDashboardDestination("Orders", in: app)
        tapWhenReady(app.buttons["orders.add"], timeout: transitionTimeout)
        tapWhenReady(app.buttons["orders.form.template.choose"], timeout: transitionTimeout)
        tapWhenReady(
            app.buttons["orders.template.use.starter-template-two-tier-wedding"],
            timeout: transitionTimeout
        )

        XCTAssertEqual(
            app.textFields["orders.form.title"].value as? String,
            "Two-Tier Wedding Cake"
        )
        let summary = app.staticTexts["orders.form.cakeSpecification.summary"]
        XCTAssertTrue(summary.waitForExistence(timeout: transitionTimeout))
        XCTAssertTrue(summary.label.contains("Wedding cake"))
        XCTAssertTrue(summary.label.contains("2 tiers"))
        XCTAssertFalse(summary.label.contains("sponge"))

        let customerName = app.textFields["orders.form.customerName"]
        scrollToHittable(customerName, in: app, timeout: transitionTimeout)
        XCTAssertNotEqual(customerName.value as? String, "Amy")
        let quotedPrice = app.textFields["orders.form.quotedPrice"]
        scrollToHittable(quotedPrice, in: app, timeout: transitionTimeout)
        XCTAssertNotEqual(quotedPrice.value as? String, "150")
    }

    func testOrderPersistsStructuredCakeRequirementsAndSummary() throws {
        let app = makeApp()
        let transitionTimeout: TimeInterval = 15
        app.launch()

        openDashboardDestination("Orders", in: app)
        tapWhenReady(app.buttons["orders.add"], timeout: transitionTimeout)
        XCTAssertTrue(app.navigationBars["Add Order"].waitForExistence(timeout: transitionTimeout))

        typeText("Floral Celebration", into: app.textFields["orders.form.title"])
        dismissKeyboard(in: app)
        let servings = app.textFields["orders.form.cakeSpecification.servings"]
        scrollToHittable(servings, in: app, timeout: transitionTimeout)
        typeText("28", into: servings)
        dismissKeyboard(in: app)
        tapWhenReady(app.buttons["Use suggested weight: 2 kg"], timeout: transitionTimeout)

        let customerName = app.textFields["orders.form.customerName"]
        scrollToHittable(customerName, in: app, timeout: transitionTimeout)
        typeText("Amy", into: customerName)
        dismissKeyboard(in: app)
        scrollToHittable(app.buttons["orders.form.save"], in: app, timeout: transitionTimeout)
        tapWhenReady(app.buttons["orders.form.save"], timeout: transitionTimeout)

        let orderRow = app.buttons.matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
                "orders.item.",
                "Floral Celebration"
            )
        ).firstMatch
        tapWhenReady(orderRow, timeout: transitionTimeout)
        let summary = app.staticTexts["orders.detail.cakeSpecification.summary"]
        assertExistsAfterScrolling(summary, in: app, timeout: transitionTimeout)
        XCTAssertTrue(summary.label.contains("28 servings (2 kg)"))
        XCTAssertTrue(summary.label.contains("standard box"))

        tapWhenReady(app.buttons["orders.detail.edit"], timeout: transitionTimeout)
        XCTAssertTrue(app.navigationBars["Edit Order"].waitForExistence(timeout: transitionTimeout))
        let reopenedServings = app.textFields["orders.form.cakeSpecification.servings"]
        scrollToHittable(reopenedServings, in: app, timeout: transitionTimeout)
        XCTAssertEqual(reopenedServings.value as? String, "28")
        XCTAssertEqual(
            app.textFields["orders.form.cakeSpecification.weight"].value as? String,
            "2"
        )
        XCTAssertTrue(
            app.staticTexts["orders.form.cakeSpecification.summary"]
                .waitForExistence(timeout: transitionTimeout)
        )
    }

    func testOrderCanBeAddedAndListed() throws {
        let app = makeApp()
        let transitionTimeout: TimeInterval = 15
        app.launch()

        openDashboardDestination("Orders", in: app)
        assertScreenVisible("screen.orders", in: app, timeout: transitionTimeout)
        XCTAssertTrue(app.staticTexts["No orders yet"].waitForExistence(timeout: transitionTimeout))

        addOrder(named: "Vanilla Birthday", notes: "Pink flowers", customerName: "Amy", in: app)

        assertScreenVisible("screen.orders", in: app, timeout: transitionTimeout)
        XCTAssertTrue(app.staticTexts["Vanilla Birthday"].waitForExistence(timeout: transitionTimeout))
        XCTAssertTrue(app.staticTexts["Amy"].waitForExistence(timeout: transitionTimeout))

        let statusButton = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "orders.item.status.")
        )
        .firstMatch
        assertExistsAfterScrolling(statusButton, in: app, timeout: transitionTimeout)
        tapWhenReady(statusButton, timeout: transitionTimeout)
        let draftStatusOption = app.buttons["Draft"]
        XCTAssertTrue(draftStatusOption.waitForExistence(timeout: transitionTimeout))
        tapWhenReady(app.buttons["Confirmed"], timeout: transitionTimeout)
        XCTAssertFalse(app.buttons["orders.row.confirmStatus"].exists)

        let orderRow = app.buttons.matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
                "orders.item.",
                "Vanilla Birthday"
            )
        ).firstMatch
        tapWhenReady(orderRow, timeout: transitionTimeout)
        XCTAssertTrue(app.staticTexts["orders.detail.status"].label.contains("Confirmed"))
    }

    func testOrderCanBeOpenedFromListAndViewed() throws {
        let app = makeApp()
        let transitionTimeout: TimeInterval = 15
        app.launch()

        openDashboardDestination("Orders", in: app)
        assertScreenVisible("screen.orders", in: app, timeout: transitionTimeout)

        addOrder(
            named: "Vanilla Birthday",
            notes: "Pink flowers",
            customerName: "Amy",
            cakeMessage: "Happy Birthday Amy",
            quotedPrice: "125.50",
            depositPaid: "25.50",
            paymentNotes: "Bank transfer",
            in: app
        )

        assertScreenVisible("screen.orders", in: app, timeout: transitionTimeout)
        XCTAssertTrue(app.staticTexts["Vanilla Birthday"].waitForExistence(timeout: transitionTimeout))
        let orderRow = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "orders.item."))
            .firstMatch
        tapWhenReady(orderRow)

        XCTAssertTrue(app.staticTexts["orders.detail.cake"].waitForExistence(timeout: transitionTimeout))
        XCTAssertTrue(app.staticTexts["orders.detail.overview.message"].waitForExistence(timeout: transitionTimeout))
        assertExistsAfterScrolling(app.staticTexts["orders.detail.customerName"], in: app, timeout: transitionTimeout)
        assertExistsAfterScrolling(app.staticTexts["orders.detail.cakeNotes"], in: app, timeout: transitionTimeout)
        assertExistsAfterScrolling(app.staticTexts["orders.detail.message"], in: app, timeout: transitionTimeout)
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Happy Birthday Amy"))
                .firstMatch
                .waitForExistence(timeout: transitionTimeout)
        )
        assertExistsAfterScrolling(app.staticTexts["orders.detail.paymentStatus"], in: app, timeout: transitionTimeout)
        assertExistsAfterScrolling(app.staticTexts["orders.detail.quotedPrice"], in: app, timeout: transitionTimeout)
        assertExistsAfterScrolling(app.staticTexts["orders.detail.depositPaid"], in: app, timeout: transitionTimeout)
        assertExistsAfterScrolling(app.staticTexts["orders.detail.balanceDue"], in: app, timeout: transitionTimeout)
    }

    func testOrderCanBeDuplicatedIntoAnUnsavedDraft() throws {
        let app = makeApp()
        let transitionTimeout: TimeInterval = 15
        app.launch()

        openDashboardDestination("Orders", in: app)
        assertScreenVisible("screen.orders", in: app, timeout: transitionTimeout)
        addOrder(
            named: "Reusable Birthday Cake",
            notes: "Pink flowers",
            customerName: "Amy",
            cakeMessage: "Happy Birthday",
            quotedPrice: "125.50",
            depositPaid: "25.50",
            paymentNotes: "Bank transfer",
            in: app
        )

        let orderRow = app.buttons.matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
                "orders.item.",
                "Reusable Birthday Cake"
            )
        ).firstMatch
        tapWhenReady(orderRow, timeout: transitionTimeout)
        XCTAssertTrue(app.staticTexts["orders.detail.cake"].waitForExistence(timeout: transitionTimeout))

        tapWhenReady(app.buttons["orders.detail.duplicate"], timeout: transitionTimeout)

        XCTAssertTrue(app.navigationBars["Add Order"].waitForExistence(timeout: transitionTimeout))
        XCTAssertEqual(
            app.textFields["orders.form.title"].value as? String,
            "Reusable Birthday Cake"
        )
        XCTAssertEqual(app.textFields["orders.form.cakeNotes"].value as? String, "Pink flowers")
        XCTAssertEqual(
            app.textFields["orders.form.cakeMessage"].value as? String,
            "Happy Birthday"
        )
        let duplicatedCustomerName = app.textFields["orders.form.customerName"]
        scrollToHittable(duplicatedCustomerName, in: app, timeout: transitionTimeout)
        XCTAssertEqual(duplicatedCustomerName.value as? String, "Amy")
        scrollToHittable(app.textFields["orders.form.quotedPrice"], in: app, timeout: transitionTimeout)
        XCTAssertNotEqual(app.textFields["orders.form.quotedPrice"].value as? String, "125.50")
        XCTAssertNotEqual(app.textFields["orders.form.depositPaid"].value as? String, "25.50")
        let duplicatedPaymentNotes = app.textFields["orders.form.paymentNotes"]
        scrollToHittable(duplicatedPaymentNotes, in: app, timeout: transitionTimeout)
        XCTAssertNotEqual(duplicatedPaymentNotes.value as? String, "Bank transfer")

        tapWhenReady(app.buttons["orders.form.cancel"], timeout: transitionTimeout)
        assertScreenVisible("screen.orders", in: app, timeout: transitionTimeout)
        XCTAssertEqual(
            app.staticTexts.matching(NSPredicate(format: "label == %@", "Reusable Birthday Cake"))
                .count,
            1
        )
    }

    func testReusableOrderTemplateCanBeSavedAndAppliedWithoutCommercialData() throws {
        let app = makeApp()
        let transitionTimeout: TimeInterval = 15
        app.launch()

        openDashboardDestination("Orders", in: app)
        assertScreenVisible("screen.orders", in: app, timeout: transitionTimeout)
        tapWhenReady(app.buttons["orders.add"], timeout: transitionTimeout)
        XCTAssertTrue(app.navigationBars["Add Order"].waitForExistence(timeout: transitionTimeout))
        typeText("Chocolate Celebration", into: app.textFields["orders.form.title"])
        dismissKeyboard(in: app)
        scrollToHittable(app.textFields["orders.form.customerName"], in: app, timeout: transitionTimeout)
        typeText("Amy", into: app.textFields["orders.form.customerName"])
        dismissKeyboard(in: app)
        scrollToHittable(app.textFields["orders.form.quotedPrice"], in: app, timeout: transitionTimeout)
        typeText("150", into: app.textFields["orders.form.quotedPrice"])
        dismissKeyboard(in: app)
        scrollToTop(in: app)
        scrollToHittable(app.buttons["orders.form.template.save"], in: app, timeout: transitionTimeout)
        tapWhenReady(app.buttons["orders.form.template.save"], timeout: transitionTimeout)
        let templateAlert = app.alerts["Save Order Template"]
        XCTAssertTrue(templateAlert.waitForExistence(timeout: transitionTimeout))
        typeText("Chocolate Standard", into: templateAlert.textFields.firstMatch)
        tapExisting(templateAlert.buttons["Save"], timeout: transitionTimeout)
        XCTAssertTrue(templateAlert.waitForNonExistence(timeout: transitionTimeout))
        tapWhenReady(app.buttons["orders.form.cancel"], timeout: transitionTimeout)
        assertScreenVisible("screen.orders", in: app, timeout: transitionTimeout)

        tapWhenReady(app.buttons["orders.add"], timeout: transitionTimeout)
        XCTAssertTrue(app.navigationBars["Add Order"].waitForExistence(timeout: transitionTimeout))
        tapWhenReady(app.buttons["orders.form.template.choose"], timeout: transitionTimeout)
        XCTAssertTrue(app.navigationBars["Order Templates"].waitForExistence(timeout: transitionTimeout))
        tapWhenReady(
            app.buttons.matching(
                NSPredicate(format: "identifier BEGINSWITH %@", "orders.template.use.")
            ).firstMatch,
            timeout: transitionTimeout
        )

        XCTAssertTrue(app.navigationBars["Add Order"].waitForExistence(timeout: transitionTimeout))
        XCTAssertEqual(
            app.textFields["orders.form.title"].value as? String,
            "Chocolate Celebration"
        )
        let templatedCustomerName = app.textFields["orders.form.customerName"]
        scrollToHittable(templatedCustomerName, in: app, timeout: transitionTimeout)
        XCTAssertNotEqual(templatedCustomerName.value as? String, "Amy")
        scrollToHittable(app.textFields["orders.form.quotedPrice"], in: app, timeout: transitionTimeout)
        XCTAssertNotEqual(app.textFields["orders.form.quotedPrice"].value as? String, "150")
    }

    func testOrderDetailCanMarkPaymentPaid() throws {
        let app = makeApp()
        let transitionTimeout: TimeInterval = 15
        app.launch()

        openDashboardDestination("Orders", in: app, timeout: transitionTimeout)
        assertScreenVisible("screen.orders", in: app, timeout: transitionTimeout)
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
        XCTAssertTrue(app.staticTexts["orders.detail.cake"].waitForExistence(timeout: transitionTimeout))

        let paymentMenu = app.buttons["orders.detail.paymentStatusMenu"]
        scrollToHittable(paymentMenu, in: app, timeout: transitionTimeout)
        tapWhenReady(paymentMenu, timeout: transitionTimeout)
        tapExisting(app.buttons["orders.detail.payment.paid"], timeout: transitionTimeout)

        let paymentStatus = app.staticTexts.matching(identifier: "orders.detail.paymentStatus").firstMatch
        assertExistsAfterScrolling(paymentStatus, in: app, timeout: transitionTimeout)
        XCTAssertTrue(paymentStatus.label.contains("Paid"))
        let depositPaid = app.staticTexts.matching(identifier: "orders.detail.depositPaid").firstMatch
        assertExistsAfterScrolling(depositPaid, in: app, timeout: transitionTimeout)
        XCTAssertTrue(depositPaid.label.contains("125"))
        let balanceDue = app.staticTexts.matching(identifier: "orders.detail.balanceDue").firstMatch
        assertExistsAfterScrolling(balanceDue, in: app, timeout: transitionTimeout)
        XCTAssertTrue(balanceDue.label.contains("0"))

        let paymentActions = app.buttons.matching(
            NSPredicate(format: "label == %@", "Payment Actions")
        ).firstMatch
        scrollToHittable(paymentActions, in: app, timeout: transitionTimeout)
        tapWhenReady(paymentActions, timeout: transitionTimeout)
        tapExisting(app.buttons["Void Payment"], timeout: transitionTimeout)
        XCTAssertTrue(
            app.textFields["Reason (optional)"]
                .waitForExistence(timeout: transitionTimeout)
        )
        XCTAssertTrue(
            app.buttons["Void Payment"]
                .waitForExistence(timeout: transitionTimeout)
        )
        tapExisting(
            app.buttons["Cancel"],
            timeout: transitionTimeout
        )
    }

    func testOrderShowsDueRemindersAndReminderPlan() throws {
        let app = makeApp()
        let transitionTimeout: TimeInterval = 15
        let orderTitle = "Reminder Vanilla Birthday"
        app.launchEnvironment["CLOUDBAKE_SEED_ORDER_REMINDER_FIXTURE"] = "1"
        app.launch()

        openDashboardDestination("Orders", in: app)
        assertScreenVisible("screen.orders", in: app, timeout: transitionTimeout)

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

        XCTAssertTrue(app.staticTexts["orders.detail.cake"].waitForExistence(timeout: transitionTimeout))
        assertExistsAfterScrolling(app.staticTexts["orders.detail.reminder.1"], in: app, timeout: transitionTimeout)
    }

    func testOrderReminderPlanCanBeDisabledAndPersists() throws {
        let app = makeApp()
        let transitionTimeout: TimeInterval = 15
        app.launch()

        openDashboardDestination("Orders", in: app, timeout: transitionTimeout)
        addOrder(
            named: "Reminder Choice Cake",
            notes: "Reminder acceptance",
            customerName: "Amy",
            in: app,
            timeout: transitionTimeout
        )
        let orderRow = app.buttons.matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
                "orders.item.",
                "Reminder Choice Cake"
            )
        )
        .firstMatch
        tapWhenReady(orderRow, timeout: transitionTimeout)
        tapWhenReady(app.buttons["orders.detail.edit"], timeout: transitionTimeout)

        var reminderPicker = app.segmentedControls["orders.form.reminderMode"]
        scrollToHittable(reminderPicker, in: app, timeout: transitionTimeout)
        tapWhenReady(reminderPicker.buttons["Off"], timeout: transitionTimeout)
        tapWhenReady(app.buttons["orders.form.save"], timeout: transitionTimeout)

        XCTAssertTrue(
            app.staticTexts["orders.detail.cake"]
                .waitForExistence(timeout: transitionTimeout)
        )
        tapWhenReady(app.buttons["orders.detail.edit"], timeout: transitionTimeout)
        reminderPicker = app.segmentedControls["orders.form.reminderMode"]
        scrollToHittable(reminderPicker, in: app, timeout: transitionTimeout)
        XCTAssertTrue(reminderPicker.buttons["Off"].isSelected)
    }

    func testOrderShowsProjectedIngredientShortageAcrossActiveOrders() throws {
        let app = makeApp()
        let transitionTimeout: TimeInterval = 15
        app.launchEnvironment["CLOUDBAKE_SEED_PROJECTED_DEMAND_FIXTURE"] = "1"
        app.launch()

        openDashboardDestination("Orders", in: app, timeout: transitionTimeout)
        assertScreenVisible("screen.orders", in: app, timeout: transitionTimeout)
        tapWhenReady(app.buttons["orders.item.order-ui-projected-1"], timeout: transitionTimeout)

        let warning = app.descendants(matching: .any)[
            "orders.detail.ingredientShortage.inventory-ui-projected-flour"
        ]
        assertExistsAfterScrolling(warning, in: app, timeout: transitionTimeout)
        XCTAssertTrue(warning.label.contains("600 g"))
        XCTAssertTrue(warning.label.contains("500 g"))

        let reservation = app.descendants(matching: .any)[
            "orders.detail.inventoryReservation.inventory-ui-projected-flour"
        ]
        assertExistsAfterScrolling(reservation, in: app, timeout: transitionTimeout)
        XCTAssertTrue(reservation.label.contains("Projected cake flour"))
        XCTAssertTrue(reservation.label.contains("300 g"))
    }

    func testOrderIngredientCostShowsPartialTotalAndMissingPriceWarning() throws {
        let app = makeApp()
        let transitionTimeout: TimeInterval = 15
        app.launchEnvironment["CLOUDBAKE_SEED_PROJECTED_DEMAND_FIXTURE"] = "1"
        app.launch()

        openDashboardDestination("Orders", in: app, timeout: transitionTimeout)
        tapWhenReady(app.buttons["orders.item.order-ui-projected-1"], timeout: transitionTimeout)

        let ingredientCost = app.buttons["orders.detail.ingredientCost"]
        app.swipeUp()
        scrollToHittable(ingredientCost, in: app, timeout: transitionTimeout)
        tapWhenReady(ingredientCost, timeout: transitionTimeout)

        XCTAssertTrue(app.staticTexts["orders.ingredientCost.total"].waitForExistence(timeout: transitionTimeout))
        XCTAssertTrue(app.descendants(matching: .any)["orders.ingredientCost.warning"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["orders.ingredientCost.line.inventory-ui-projected-flour"].exists)
    }

    func testOrderFormShowsIngredientCostWhileQuoting() throws {
        let app = makeApp()
        let transitionTimeout: TimeInterval = 15
        app.launchEnvironment["CLOUDBAKE_SEED_PROJECTED_DEMAND_FIXTURE"] = "1"
        app.launch()

        openDashboardDestination("Orders", in: app, timeout: transitionTimeout)
        tapWhenReady(app.buttons["orders.add"], timeout: transitionTimeout)

        let recipeField = app.buttons["orders.form.recipe"]
        scrollToHittable(recipeField, in: app, timeout: transitionTimeout)
        tapWhenReady(recipeField, timeout: transitionTimeout)
        tapWhenReady(
            app.buttons["orders.recipeSelection.recipe.recipe-ui-projected-cake"],
            timeout: transitionTimeout
        )

        let ingredientCost = app.descendants(matching: .any)["orders.form.ingredientCost"]
        assertExistsAfterScrolling(ingredientCost, in: app, timeout: transitionTimeout)
        assertExistsAfterScrolling(
            app.descendants(matching: .any)["orders.form.ingredientCost.warning"],
            in: app,
            timeout: transitionTimeout
        )
        assertExistsAfterScrolling(
            app.textFields["orders.form.quotedPrice"],
            in: app,
            timeout: transitionTimeout
        )
    }

    func testOrderCanBeEditedFromDetail() throws {
        let app = makeApp()
        let transitionTimeout: TimeInterval = 15
        app.launch()

        openDashboardDestination("Orders", in: app)
        assertScreenVisible("screen.orders", in: app, timeout: transitionTimeout)
        addOrder(named: "Vanilla Birthday", notes: "Pink flowers", customerName: "Amy", in: app)

        tapWhenReady(
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "orders.item."))
                .firstMatch,
            timeout: transitionTimeout
        )
        XCTAssertTrue(app.staticTexts["orders.detail.cake"].waitForExistence(timeout: transitionTimeout))
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

        let messageField = app.textFields["orders.form.cakeMessage"]
        tapWhenReady(messageField, timeout: transitionTimeout)
        messageField.typeText("Happy 7th")

        tapWhenReady(app.buttons["orders.form.save"], timeout: transitionTimeout)

        XCTAssertTrue(app.staticTexts["orders.detail.cake"].waitForExistence(timeout: transitionTimeout))
        assertExistsAfterScrolling(app.staticTexts["orders.detail.cakeNotes"], in: app, timeout: transitionTimeout)
        assertExistsAfterScrolling(app.staticTexts["orders.detail.message"], in: app, timeout: transitionTimeout)
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Gold leaf"))
                .firstMatch
                .waitForExistence(timeout: transitionTimeout)
        )
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Happy 7th"))
                .firstMatch
                .waitForExistence(timeout: transitionTimeout)
        )
    }

    func testOrderChecklistItemCanBeAddedAndCompleted() throws {
        let app = makeApp()
        let transitionTimeout: TimeInterval = 15
        app.launch()

        openDashboardDestination("Orders", in: app, timeout: transitionTimeout)
        assertScreenVisible("screen.orders", in: app, timeout: transitionTimeout)
        addOrder(named: "Vanilla Birthday", notes: "Pink flowers", customerName: "Amy", in: app)

        tapWhenReady(
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "orders.item."))
                .firstMatch,
            timeout: transitionTimeout
        )
        XCTAssertTrue(app.staticTexts["orders.detail.cake"].waitForExistence(timeout: transitionTimeout))

        let checklistTitle = app.textFields["orders.detail.checklist.title"]
        scrollToHittable(checklistTitle, in: app, timeout: transitionTimeout)
        typeText("Crumb coat", into: checklistTitle, timeout: transitionTimeout)
        let addChecklistButton = app.buttons["orders.detail.checklist.add"]
        scrollToHittable(addChecklistButton, in: app, timeout: transitionTimeout)
        tapExisting(addChecklistButton, timeout: transitionTimeout)

        let checklistItem = app.descendants(matching: .any).matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@",
                "orders.detail.checklist.item."
            )
        )
        .firstMatch
        XCTAssertTrue(checklistItem.waitForExistence(timeout: transitionTimeout))
        XCTAssertEqual(checklistItem.value as? String, "Incomplete")

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
        XCTAssertTrue(app.staticTexts["orders.detail.cake"].waitForExistence(timeout: transitionTimeout))
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

        openDashboardDestination("Orders", in: app, timeout: transitionTimeout)
        assertScreenVisible("screen.orders", in: app, timeout: transitionTimeout)

        let orderRow = app.buttons.matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
                "orders.item.",
                "Photo Vanilla Birthday"
            )
        )
        .firstMatch
        tapWhenReady(orderRow, timeout: transitionTimeout)

        XCTAssertTrue(app.staticTexts["orders.detail.cake"].waitForExistence(timeout: transitionTimeout))
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
        scrollToHittable(referencePreview, in: app, timeout: transitionTimeout)
        tapWhenReady(referencePreview, timeout: transitionTimeout)
        let referenceMetadata = app.descendants(matching: .any)["orders.detail.photos.preview.screen"]
        XCTAssertTrue(referenceMetadata.waitForExistence(timeout: transitionTimeout))
        XCTAssertTrue(referenceMetadata.label.contains("Customer sketch"))
        XCTAssertTrue(referenceMetadata.label.contains("Reference Photo"))
        tapWhenReady(app.buttons["orders.detail.photos.preview.editCaption"], timeout: transitionTimeout)
        XCTAssertTrue(app.navigationBars["Photo Caption"].waitForExistence(timeout: transitionTimeout))
        let captionField = app.textFields["orders.detail.photos.caption.text"]
        tapWhenReady(captionField, timeout: transitionTimeout)
        captionField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 30))
        captionField.typeText("Lace and pearls")
        tapWhenReady(app.buttons["orders.detail.photos.caption.save"], timeout: transitionTimeout)
        XCTAssertTrue(referenceMetadata.waitForExistence(timeout: transitionTimeout))
        XCTAssertTrue(referenceMetadata.label.contains("Lace and pearls"))
        tapWhenReady(app.buttons["orders.detail.photos.preview.close"], timeout: transitionTimeout)
        XCTAssertTrue(app.staticTexts["orders.detail.cake"].waitForExistence(timeout: transitionTimeout))
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
        scrollToHittable(finalPreview, in: app, timeout: transitionTimeout)
        tapWhenReady(finalPreview, timeout: transitionTimeout)
        let finalMetadata = app.descendants(matching: .any)["orders.detail.photos.preview.screen"]
        XCTAssertTrue(finalMetadata.waitForExistence(timeout: transitionTimeout))
        XCTAssertTrue(finalMetadata.label.contains("Finished cake"))
        XCTAssertTrue(finalMetadata.label.contains("Final Cake Photo"))
        tapWhenReady(app.buttons["orders.detail.photos.preview.promoteDesign"], timeout: transitionTimeout)
        XCTAssertTrue(app.navigationBars["Save Design"].waitForExistence(timeout: transitionTimeout))
        let designNameField = app.textFields["orders.detail.photos.design.name"]
        tapWhenReady(designNameField, timeout: transitionTimeout)
        designNameField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 30))
        designNameField.typeText("Pink Pearl Cake")
        tapWhenReady(app.buttons["orders.detail.photos.design.save"], timeout: transitionTimeout)
        XCTAssertTrue(app.staticTexts["orders.detail.cake"].waitForExistence(timeout: transitionTimeout))
        scrollToTop(in: app)
        assertExistsAfterScrolling(app.staticTexts["orders.detail.designName"], in: app, timeout: transitionTimeout)
        XCTAssertTrue(app.staticTexts["orders.detail.designName"].label.contains("Pink Pearl Cake"))
    }

    func testOrderShowsLinkedCustomerContext() throws {
        let app = makeApp()
        let transitionTimeout: TimeInterval = 25
        app.launchEnvironment["CLOUDBAKE_SEED_ORDER_CUSTOMER_LINK_FIXTURE"] = "1"
        app.launch()

        openDashboardDestination("Orders", in: app, timeout: transitionTimeout)
        assertScreenVisible("screen.orders", in: app, timeout: transitionTimeout)
        tapWhenReady(app.buttons["orders.item.order-ui-fixture-customer-link"], timeout: transitionTimeout)

        XCTAssertTrue(app.staticTexts["orders.detail.cake"].waitForExistence(timeout: transitionTimeout))
        assertExistsAfterScrolling(app.staticTexts["orders.detail.customerName"], in: app, timeout: transitionTimeout)
        let allergyText = app.staticTexts["orders.detail.customerAllergies"]
        assertExistsAfterScrolling(allergyText, in: app, timeout: transitionTimeout)
        XCTAssertTrue(allergyText.label.contains("Nuts"))
    }

    func testOrderCustomerCreationOffersNativeEntryChoices() throws {
        let app = makeApp()
        let transitionTimeout: TimeInterval = 25
        app.launch()

        openDashboardDestination("Orders", in: app, timeout: transitionTimeout)
        tapWhenReady(
            app.buttons["orders.add"],
            waitingFor: app.navigationBars["Add Order"],
            in: app,
            timeout: transitionTimeout
        )

        let customerRecordButton = app.buttons["orders.form.customerRecord"]
        scrollToHittable(customerRecordButton, in: app, timeout: transitionTimeout)
        tapWhenReady(
            customerRecordButton,
            waitingFor: app.navigationBars["Customer Record"],
            in: app,
            timeout: transitionTimeout
        )

        tapWhenReady(app.buttons["orders.customerSelection.newCustomer"], timeout: transitionTimeout)
        XCTAssertTrue(app.staticTexts["Add Customer"].waitForExistence(timeout: transitionTimeout))
        XCTAssertTrue(nativeDialogAction(labeled: "Import From Contacts", in: app).exists)
        XCTAssertTrue(nativeDialogAction(labeled: "Enter Manually", in: app).exists)
        dismissNativeDialog(titled: "Add Customer", in: app)
    }

    func testOrderCanCreateAndLinkNewCustomerFromSelection() throws {
        let app = makeApp()
        let transitionTimeout: TimeInterval = 25
        app.launchEnvironment["CLOUDBAKE_TEST_DIRECT_ORDER_CUSTOMER_ENTRY"] = "1"
        app.launch()

        openDashboardDestination("Orders", in: app, timeout: transitionTimeout)
        assertScreenVisible("screen.orders", in: app, timeout: transitionTimeout)
        tapWhenReady(
            app.buttons["orders.add"],
            waitingFor: app.navigationBars["Add Order"],
            in: app,
            timeout: transitionTimeout
        )

        typeText("Chocolate Celebration", into: app.textFields["orders.form.title"], timeout: transitionTimeout)
        dismissKeyboard(in: app)

        let customerRecordButton = app.buttons["orders.form.customerRecord"]
        scrollToHittable(customerRecordButton, in: app, timeout: transitionTimeout)
        tapWhenReady(
            customerRecordButton,
            waitingFor: app.navigationBars["Customer Record"],
            in: app,
            timeout: transitionTimeout
        )

        tapWhenReady(
            app.buttons["orders.customerSelection.newCustomer"],
            waitingFor: app.navigationBars["Add Customer"],
            in: app,
            timeout: transitionTimeout
        )
        typeText("Maya", into: app.textFields["customers.form.name"], timeout: transitionTimeout)
        dismissKeyboard(in: app)
        typeText("5550303", into: app.textFields["customers.form.phone"], timeout: transitionTimeout)
        dismissKeyboard(in: app)
        tapWhenReady(
            app.buttons["customers.form.save"],
            waitingFor: app.navigationBars["Add Order"],
            in: app,
            timeout: transitionTimeout
        )
        XCTAssertEqual(app.textFields["orders.form.customerName"].value as? String, "Maya")
        tapWhenReady(app.buttons["orders.form.save"], timeout: transitionTimeout)

        assertScreenVisible("screen.orders", in: app, timeout: transitionTimeout)
        let orderRow = app.buttons.matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
                "orders.item.",
                "Chocolate Celebration"
            )
        )
        .firstMatch
        scrollToHittable(orderRow, in: app, timeout: transitionTimeout)
        tapWhenReady(orderRow, timeout: transitionTimeout)

        XCTAssertTrue(app.staticTexts["orders.detail.cake"].waitForExistence(timeout: transitionTimeout))
        assertExistsAfterScrolling(app.staticTexts["orders.detail.customerName"], in: app, timeout: transitionTimeout)
    }

    func testOrderCanLinkRecipeFromSearchableSelection() throws {
        let app = makeApp()
        let transitionTimeout: TimeInterval = 25
        app.launch()

        openDashboardDestination("Recipes", in: app, timeout: transitionTimeout)
        addRecipe(named: "Vanilla Sponge", notes: "Birthday base", in: app)
        returnToDashboard(in: app, timeout: transitionTimeout)

        openDashboardDestination("Orders", in: app, timeout: transitionTimeout)
        assertScreenVisible("screen.orders", in: app, timeout: transitionTimeout)
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
        let recipe = app.buttons.matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
                "orders.recipeSelection.recipe.",
                "Vanilla Sponge"
            )
        )
        .firstMatch
        scrollToHittable(recipe, in: app, timeout: transitionTimeout)
        tapWhenReady(
            recipe,
            timeout: transitionTimeout
        )
        XCTAssertTrue(app.navigationBars["Add Order"].waitForExistence(timeout: transitionTimeout))

        tapWhenReady(app.buttons["orders.form.save"], timeout: transitionTimeout)

        assertScreenVisible("screen.orders", in: app, timeout: transitionTimeout)
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

        XCTAssertTrue(app.staticTexts["orders.detail.cake"].waitForExistence(timeout: transitionTimeout))
        let recipeName = app.staticTexts["orders.detail.recipeName"]
        assertExistsAfterScrolling(recipeName, in: app, timeout: transitionTimeout)
        XCTAssertTrue(recipeName.label.contains("Vanilla Sponge"))
    }

    func testOrderCanLinkDesignFromSearchableSelection() throws {
        let app = makeApp()
        let transitionTimeout: TimeInterval = 25
        app.launchEnvironment["CLOUDBAKE_SEED_CAKE_DESIGN_FIXTURE"] = "1"
        app.launch()

        openDashboardDestination("Orders", in: app, timeout: transitionTimeout)
        assertScreenVisible("screen.orders", in: app, timeout: transitionTimeout)
        tapWhenReady(app.buttons["orders.add"], timeout: transitionTimeout)
        XCTAssertTrue(app.navigationBars["Add Order"].waitForExistence(timeout: transitionTimeout))

        typeText("Vanilla Birthday", into: app.textFields["orders.form.title"], timeout: transitionTimeout)
        typeText("Pink flowers", into: app.textFields["orders.form.cakeNotes"], timeout: transitionTimeout)
        dismissKeyboard(in: app)

        let designField = app.buttons["orders.form.design"]
        scrollToHittable(designField, in: app, timeout: transitionTimeout)
        tapWhenReady(designField, timeout: transitionTimeout)
        XCTAssertTrue(app.navigationBars["Choose Design"].waitForExistence(timeout: transitionTimeout))
        let designSearch = app.textFields["orders.designSelection.search"]
        XCTAssertTrue(designSearch.waitForExistence(timeout: transitionTimeout))
        typeText("Pink Floral", into: designSearch, timeout: transitionTimeout)
        let floralDesign = app.descendants(matching: .any)[
            "orders.designSelection.design.design-ui-fixture-floral"
        ]
        XCTAssertTrue(floralDesign.waitForExistence(timeout: transitionTimeout))
        tapWhenReady(floralDesign, timeout: transitionTimeout)
        XCTAssertTrue(app.navigationBars["Add Order"].waitForExistence(timeout: transitionTimeout))

        let customerNameField = app.textFields["orders.form.customerName"]
        scrollToHittable(customerNameField, in: app, timeout: transitionTimeout)
        typeText("Amy", into: customerNameField, timeout: transitionTimeout)
        dismissKeyboard(in: app)

        tapWhenReady(app.buttons["orders.form.save"], timeout: transitionTimeout)

        assertScreenVisible("screen.orders", in: app, timeout: transitionTimeout)
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

        XCTAssertTrue(app.staticTexts["orders.detail.cake"].waitForExistence(timeout: transitionTimeout))
        let designName = app.staticTexts["orders.detail.designName"]
        assertExistsAfterScrolling(designName, in: app, timeout: transitionTimeout)
        XCTAssertTrue(designName.label.contains("Pink Floral Cake"))
        assertExistsAfterScrolling(app.staticTexts["orders.detail.designNotes"], in: app, timeout: transitionTimeout)
        let designThumbnail = app.buttons["orders.detail.designPhotoThumbnail"]
        scrollToHittable(designThumbnail, in: app, timeout: transitionTimeout)
        tapWhenReady(designThumbnail, timeout: transitionTimeout)
        XCTAssertTrue(
            app.descendants(matching: .any)["orders.detail.designPhotoPreview"]
                .waitForExistence(timeout: transitionTimeout)
        )
        XCTAssertTrue(app.navigationBars["Pink Floral Cake"].exists)
        tapWhenReady(app.buttons["orders.detail.designPhotoPreview.done"], timeout: transitionTimeout)
        XCTAssertTrue(app.staticTexts["orders.detail.cake"].waitForExistence(timeout: transitionTimeout))
    }

    func testOrderCanSelectCustomerReferenceFromPhotoFirstDesignPicker() throws {
        let app = makeApp()
        let transitionTimeout: TimeInterval = 25
        app.launchEnvironment["CLOUDBAKE_SEED_ORDER_PHOTO_FIXTURE"] = "1"
        app.launch()

        openDashboardDestination("Orders", in: app, timeout: transitionTimeout)
        tapWhenReady(app.buttons["orders.add"], timeout: transitionTimeout)
        XCTAssertTrue(app.navigationBars["Add Order"].waitForExistence(timeout: transitionTimeout))

        let designField = app.buttons["orders.form.design"]
        scrollToHittable(designField, in: app, timeout: transitionTimeout)
        tapWhenReady(designField, timeout: transitionTimeout)
        XCTAssertTrue(app.navigationBars["Choose Design"].waitForExistence(timeout: transitionTimeout))

        let search = app.textFields["orders.designSelection.search"]
        typeText("Customer sketch", into: search, timeout: transitionTimeout)
        let reference = app.descendants(matching: .any)[
            "orders.designSelection.reference.design-ui-fixture-reference"
        ]
        XCTAssertTrue(reference.waitForExistence(timeout: transitionTimeout))
        tapWhenReady(reference, timeout: transitionTimeout)

        XCTAssertTrue(app.navigationBars["Add Order"].waitForExistence(timeout: transitionTimeout))
        let returnedDesignField = app.buttons["orders.form.design"]
        scrollToHittable(returnedDesignField, in: app, timeout: transitionTimeout)
        XCTAssertTrue(returnedDesignField.label.contains("Customer sketch"))

        let titleField = app.textFields["orders.form.title"]
        scrollToTop(in: app)
        scrollToHittable(titleField, in: app, timeout: transitionTimeout)
        typeText("Customer Reference Cake", into: titleField, timeout: transitionTimeout)
        dismissKeyboard(in: app)
        let customerNameField = app.textFields["orders.form.customerName"]
        scrollToHittable(customerNameField, in: app, timeout: transitionTimeout)
        typeText("Beth", into: customerNameField, timeout: transitionTimeout)
        dismissKeyboard(in: app)
        scrollToHittable(app.buttons["orders.form.save"], in: app, timeout: transitionTimeout)
        tapWhenReady(app.buttons["orders.form.save"], timeout: transitionTimeout)

        let orderRow = app.buttons.matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
                "orders.item.",
                "Customer Reference Cake"
            )
        ).firstMatch
        scrollToHittable(orderRow, in: app, timeout: transitionTimeout)
        tapWhenReady(orderRow, timeout: transitionTimeout)

        let designThumbnail = app.buttons["orders.detail.designPhotoThumbnail"]
        scrollToHittable(designThumbnail, in: app, timeout: transitionTimeout)
        tapWhenReady(designThumbnail, timeout: transitionTimeout)
        XCTAssertTrue(app.navigationBars["Customer sketch"].waitForExistence(timeout: transitionTimeout))
        XCTAssertEqual(
            app.staticTexts["orders.detail.designPhotoPreview.source"].label,
            "Reference"
        )
        tapWhenReady(app.buttons["orders.detail.designPhotoPreview.done"], timeout: transitionTimeout)
        XCTAssertTrue(app.staticTexts["orders.detail.cake"].waitForExistence(timeout: transitionTimeout))
    }

    func testOrderCanUseLinkedRecipeToDeductInventory() throws {
        let app = makeApp()
        let transitionTimeout: TimeInterval = 15
        app.launch()

        openDashboardDestination("Inventory", in: app, timeout: transitionTimeout)
        addInventoryItem(named: "Cake flour", currentQuantity: "1000", minimumQuantity: "500", in: app)
        returnToDashboard(in: app)

        openDashboardDestination("Recipes", in: app, timeout: transitionTimeout)
        addRecipe(named: "Vanilla Sponge", notes: "Birthday base", in: app)
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "recipes.item."))
            .firstMatch
            .tap()
        XCTAssertTrue(app.buttons["recipes.detail.done"].waitForExistence(timeout: transitionTimeout))
        app.buttons["recipes.ingredient.add"].tap()
        XCTAssertTrue(app.navigationBars["Add Ingredient"].waitForExistence(timeout: transitionTimeout))
        app.textFields["recipes.ingredient.quantity"].tap()
        app.textFields["recipes.ingredient.quantity"].typeText("250")
        app.buttons["recipes.ingredient.save"].tap()
        XCTAssertTrue(app.buttons["recipes.detail.done"].waitForExistence(timeout: transitionTimeout))
        app.buttons["recipes.detail.done"].tap()
        returnToDashboard(in: app)

        openDashboardDestination("Orders", in: app, timeout: transitionTimeout)
        assertScreenVisible("screen.orders", in: app, timeout: transitionTimeout)
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

        assertScreenVisible("screen.orders", in: app, timeout: transitionTimeout)
        tapWhenReady(
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "orders.item."))
                .firstMatch,
            timeout: transitionTimeout
        )
        XCTAssertTrue(app.staticTexts["orders.detail.cake"].waitForExistence(timeout: transitionTimeout))
        assertExistsAfterScrolling(app.buttons["orders.detail.statusMenu"], in: app, timeout: transitionTimeout)
        tapWhenReady(app.buttons["orders.detail.statusMenu"], timeout: transitionTimeout)
        tapExisting(app.buttons["Confirmed"], timeout: transitionTimeout)
        let confirmedStatus = app.staticTexts["orders.detail.status"]
        XCTAssertTrue(confirmedStatus.waitForExistence(timeout: transitionTimeout))
        XCTAssertTrue(confirmedStatus.label.contains("Confirmed"))
        tapWhenReady(app.buttons["orders.detail.statusMenu"], timeout: transitionTimeout)
        tapExisting(app.buttons["Ready"], timeout: transitionTimeout)
        tapWhenReady(
            nativeDialogAction(
                identifiedBy: "orders.detail.confirmInventoryDeduction",
                in: app
            ),
            timeout: transitionTimeout
        )
        let readyStatus = app.staticTexts["orders.detail.status"]
        XCTAssertTrue(readyStatus.waitForExistence(timeout: transitionTimeout))
        XCTAssertTrue(readyStatus.label.contains("Ready"))
        app.buttons["orders.detail.done"].tap()
        returnToDashboard(in: app)

        openDashboardDestination("Inventory", in: app, timeout: transitionTimeout)
        XCTAssertTrue(app.staticTexts["Current Quantity: 500 g"].waitForExistence(timeout: transitionTimeout))
    }

    func testOrderStatusFailureIsShownImmediatelyFromDetail() throws {
        let app = makeApp(initialDestination: "orders")
        app.launchEnvironment["CLOUDBAKE_SEED_ORDER_STATUS_FAILURE_FIXTURE"] = "1"
        app.launch()

        assertScreenVisible("screen.orders", in: app)
        let orderRow = app.buttons.matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
                "orders.item.",
                "Status failure cake"
            )
        ).firstMatch
        tapWhenReady(orderRow)

        assertExistsAfterScrolling(app.buttons["orders.detail.statusMenu"], in: app)
        tapWhenReady(app.buttons["orders.detail.statusMenu"])
        tapExisting(app.buttons["Ready"])
        tapWhenReady(
            nativeDialogAction(
                identifiedBy: "orders.detail.confirmInventoryDeduction",
                in: app
            )
        )

        let error = app.sheets.staticTexts["Recipe has no ingredients to deduct."]
        XCTAssertTrue(error.waitForExistence(timeout: 5))
        XCTAssertEqual(error.label, "Recipe has no ingredients to deduct.")
        tapWhenReady(
            nativeDialogAction(
                identifiedBy: "orders.detail.statusChangeError.dismiss",
                in: app
            )
        )
        XCTAssertTrue(app.staticTexts["orders.detail.status"].label.contains("Confirmed"))
    }

    func testDraftOrderCannotBypassInventoryDeductionWhenMarkedReady() throws {
        let app = makeApp(initialDestination: "orders")
        app.launchEnvironment["CLOUDBAKE_SEED_ORDER_STATUS_FAILURE_FIXTURE"] = "1"
        app.launch()

        assertScreenVisible("screen.orders", in: app)
        let orderRow = app.buttons.matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
                "orders.item.",
                "Draft status cake"
            )
        ).firstMatch
        scrollToHittable(
            orderRow,
            in: app,
            scrollContainer: app.scrollViews["screen.orders"],
            timeout: 10
        )
        tapWhenReady(orderRow)

        assertExistsAfterScrolling(app.buttons["orders.detail.statusMenu"], in: app)
        tapWhenReady(app.buttons["orders.detail.statusMenu"])
        tapExisting(app.buttons["Ready"])

        XCTAssertTrue(
            nativeDialogAction(
                identifiedBy: "orders.detail.confirmInventoryDeduction",
                in: app
            ).waitForExistence(timeout: 5)
        )
        XCTAssertTrue(app.staticTexts["orders.detail.status"].label.contains("Draft"))
    }

    func testOrderCanContinueAfterInventoryShortageWarning() throws {
        let app = makeApp(initialDestination: "orders")
        app.launchEnvironment["CLOUDBAKE_SEED_ORDER_STATUS_FAILURE_FIXTURE"] = "1"
        app.launch()

        assertScreenVisible("screen.orders", in: app)
        let orderRow = app.buttons.matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
                "orders.item.",
                "Inventory shortage cake"
            )
        ).firstMatch
        tapWhenReady(orderRow)

        assertExistsAfterScrolling(app.buttons["orders.detail.statusMenu"], in: app)
        tapWhenReady(app.buttons["orders.detail.statusMenu"])
        tapExisting(app.buttons["Ready"])
        tapWhenReady(
            nativeDialogAction(
                identifiedBy: "orders.detail.confirmInventoryDeduction",
                in: app
            )
        )

        let warning = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "Shortage sugar: short by 50 g")
        ).firstMatch
        XCTAssertTrue(warning.waitForExistence(timeout: 5))
        XCTAssertTrue(warning.label.contains("Shortage sugar: short by 50 g"))
        dismissNativeDialog(titled: "Inventory Shortage", in: app)
        XCTAssertTrue(app.staticTexts["orders.detail.status"].label.contains("Confirmed"))

        tapWhenReady(app.buttons["orders.detail.statusMenu"])
        tapExisting(app.buttons["Ready"])
        tapWhenReady(
            nativeDialogAction(
                identifiedBy: "orders.detail.confirmInventoryDeduction",
                in: app
            )
        )
        XCTAssertTrue(warning.waitForExistence(timeout: 5))
        tapWhenReady(
            nativeDialogAction(
                identifiedBy: "orders.detail.inventoryShortage.continue",
                in: app
            )
        )

        let status = app.staticTexts["orders.detail.status"]
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        XCTAssertTrue(status.label.contains("Ready"))
    }

    func testOrderCalendarViewShowsOrders() throws {
        let app = makeApp()
        let transitionTimeout: TimeInterval = 15
        app.launch()

        openDashboardDestination("Orders", in: app)
        assertScreenVisible("screen.orders", in: app, timeout: transitionTimeout)
        addOrder(named: "Vanilla Birthday", notes: "Pink flowers", customerName: "Amy", in: app)

        let orderRow = app.buttons.matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
                "orders.item.",
                "Vanilla Birthday"
            )
        )
        .firstMatch
        assertExistsAfterScrolling(orderRow, in: app, timeout: transitionTimeout)
        XCTAssertTrue(orderRow.label.contains("Amy"))
        tapWhenReady(orderRow, timeout: transitionTimeout)
        XCTAssertTrue(app.staticTexts["orders.detail.cake"].waitForExistence(timeout: transitionTimeout))
    }

    func testCompletedOrderAppearsInCompletedTab() throws {
        let app = makeApp()
        let transitionTimeout: TimeInterval = 15
        app.launchEnvironment["CLOUDBAKE_SEED_COMPLETED_ORDER_FIXTURE"] = "1"
        app.launch()

        openDashboardDestination("Orders", in: app, timeout: transitionTimeout)
        assertScreenVisible("screen.orders", in: app, timeout: transitionTimeout)
        XCTAssertTrue(app.staticTexts["No active orders"].waitForExistence(timeout: transitionTimeout))

        let ordersScreen = app.scrollViews["screen.orders"]
        XCTAssertTrue(ordersScreen.waitForExistence(timeout: transitionTimeout))
        swipeOrderScopeLeftThroughEmptySpace(in: ordersScreen)
        let completedOrderRow = app.buttons["orders.item.order-ui-fixture-completed"]
        assertExistsAfterScrolling(completedOrderRow, in: app, timeout: transitionTimeout)
        let completedDueAt = Date(timeIntervalSince1970: 1_800_140_000)
        XCTAssertTrue(completedOrderRow.label.contains(completedDueAt.formatted(date: .abbreviated, time: .omitted)))
        XCTAssertFalse(completedOrderRow.label.contains(completedDueAt.formatted(date: .abbreviated, time: .shortened)))
        XCTAssertFalse(app.buttons["orders.item.status.order-ui-fixture-completed"].exists)
        XCTAssertTrue(app.buttons["orders.item.payment.order-ui-fixture-completed"].exists)

        swipeOrderScopeRightThroughEmptySpace(in: ordersScreen)
        XCTAssertTrue(app.staticTexts["No active orders"].waitForExistence(timeout: transitionTimeout))
    }

    func testCompletedOrdersLoadNextPageWithoutDuplicatesOrMissingRows() throws {
        let app = makeApp()
        let transitionTimeout: TimeInterval = 15
        app.launchEnvironment[
            "CLOUDBAKE_SEED_COMPLETED_ORDER_PAGINATION_FIXTURE"
        ] = "1"
        app.launch()

        openDashboardDestination(
            "Orders",
            in: app,
            timeout: transitionTimeout
        )
        let ordersScreen = app.scrollViews["screen.orders"]
        XCTAssertTrue(
            ordersScreen.waitForExistence(timeout: transitionTimeout)
        )
        swipeOrderScopeLeftThroughEmptySpace(in: ordersScreen)

        let newest = app.buttons["orders.item.order-ui-completed-page-29"]
        let oldest = app.buttons["orders.item.order-ui-completed-page-00"]
        assertExistsAfterScrolling(
            newest,
            in: app,
            scrollContainer: ordersScreen,
            timeout: transitionTimeout
        )
        XCTAssertFalse(oldest.exists)

        let loadMore = app.buttons["orders.completed.loadMore"]
        for _ in 0..<20 where !loadMore.isHittable {
            ordersScreen.swipeUp()
        }
        tapWhenReady(loadMore, timeout: transitionTimeout)

        assertExistsAfterScrolling(
            oldest,
            in: app,
            scrollContainer: ordersScreen,
            timeout: transitionTimeout
        )
        XCTAssertEqual(
            app.buttons.matching(
                NSPredicate(
                    format: "identifier BEGINSWITH %@",
                    "orders.item.order-ui-completed-page-"
                )
            ).count,
            30
        )
        XCTAssertFalse(app.buttons["orders.completed.loadMore"].exists)
    }

    func testCancelledOrderAppearsInCompletedTabWithBadge() throws {
        let app = makeApp()
        let transitionTimeout: TimeInterval = 15
        app.launch()

        openDashboardDestination("Orders", in: app, timeout: transitionTimeout)
        assertScreenVisible("screen.orders", in: app, timeout: transitionTimeout)
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

        XCTAssertTrue(app.staticTexts["orders.detail.cake"].waitForExistence(timeout: transitionTimeout))
        tapWhenReady(app.buttons["orders.detail.statusMenu"], timeout: transitionTimeout)
        tapExisting(app.buttons["Cancelled"], timeout: transitionTimeout)
        let cancelledStatus = app.staticTexts["orders.detail.status"]
        XCTAssertTrue(cancelledStatus.waitForExistence(timeout: transitionTimeout))
        XCTAssertTrue(cancelledStatus.label.contains("Cancelled"))
        app.buttons["orders.detail.done"].tap()

        assertScreenVisible("screen.orders", in: app, timeout: transitionTimeout)
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

    private func swipeOrderScopeLeftThroughEmptySpace(in ordersScreen: XCUIElement) {
        swipeOrderScopeThroughEmptySpace(in: ordersScreen, fromX: 0.88, toX: 0.12)
    }

    private func swipeOrderScopeRightThroughEmptySpace(in ordersScreen: XCUIElement) {
        swipeOrderScopeThroughEmptySpace(in: ordersScreen, fromX: 0.12, toX: 0.88)
    }

    private func swipeOrderScopeThroughEmptySpace(in ordersScreen: XCUIElement, fromX: CGFloat, toX: CGFloat) {
        let start = ordersScreen.coordinate(withNormalizedOffset: CGVector(dx: fromX, dy: 0.82))
        let end = ordersScreen.coordinate(withNormalizedOffset: CGVector(dx: toX, dy: 0.82))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

}
