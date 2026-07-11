import XCTest

final class CloudBakeOwnerUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAppLaunchesToDashboard() throws {
        let app = makeApp()
        app.launch()

        assertDashboardVisible(in: app, timeout: 5)
        XCTAssertTrue(app.staticTexts["Upcoming orders"].exists)
        XCTAssertTrue(app.staticTexts["Low inventory"].exists)
    }

    func testPrimaryNavigationDestinationsAreReachable() throws {
        let destinations = [
            ("Orders", "screen.orders"),
            ("Inventory", "screen.inventory"),
            ("More", "screen.more"),
            ("Recipes", "screen.recipes"),
            ("Customers", "screen.customers"),
            ("Designs", "screen.designs")
        ]

        for destination in destinations {
            let app = makeApp()
            app.launch()

            openDashboardDestination(destination.0, in: app)
            assertScreenVisible(destination.1, in: app, timeout: 5)
            app.terminate()
        }
    }

    func testDesignRemovalCanBeCancelledAndConfirmed() throws {
        let app = makeApp(initialDestination: "designs")
        app.launchEnvironment["CLOUDBAKE_SEED_CAKE_DESIGN_FIXTURE"] = "1"
        app.launch()

        let design = app.buttons["designs.item.design-ui-fixture-floral"]
        XCTAssertTrue(design.waitForExistence(timeout: 10))
        tapWhenReady(design)

        let remove = app.buttons["Remove Design"]
        XCTAssertTrue(remove.waitForExistence(timeout: 5))
        tapWhenReady(remove)
        let cancel = app.buttons["designs.delete.cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS %@", "image remains in Photos")
            ).firstMatch.exists
        )
        tapWhenReady(cancel)
        XCTAssertTrue(app.buttons["designs.preview.done"].exists)

        tapWhenReady(remove)
        let confirm = app.buttons["designs.delete.confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        tapWhenReady(confirm)

        XCTAssertTrue(app.staticTexts["No owner designs saved"].waitForExistence(timeout: 5))
    }

    func testDesignCanStartAnUnsavedOrderDraftWithTheDesignLinked() throws {
        let app = makeApp(initialDestination: "designs")
        app.launchEnvironment["CLOUDBAKE_SEED_CAKE_DESIGN_FIXTURE"] = "1"
        app.launch()

        let design = app.buttons["designs.item.design-ui-fixture-floral"]
        XCTAssertTrue(design.waitForExistence(timeout: 10))
        tapWhenReady(design)
        let useForNewOrder = app.buttons["designs.preview.useForNewOrder"]
        XCTAssertTrue(useForNewOrder.waitForExistence(timeout: 5))
        tapWhenReady(useForNewOrder)

        XCTAssertTrue(app.navigationBars["Add Order"].waitForExistence(timeout: 10))
        let linkedDesign = app.buttons["orders.form.design"]
        XCTAssertTrue(linkedDesign.waitForExistence(timeout: 5))
        XCTAssertTrue(linkedDesign.label.contains("Pink Floral Cake"))
        tapWhenReady(app.buttons["orders.form.cancel"])

        XCTAssertTrue(app.staticTexts["No orders yet"].waitForExistence(timeout: 5))
    }

    func testCustomerReferenceDraftShowsItsCurrentSelectedProvenance() throws {
        let app = makeApp(initialDestination: "designs")
        app.launchEnvironment["CLOUDBAKE_SEED_ORDER_PHOTO_FIXTURE"] = "1"
        app.launch()

        let reference = app.buttons["designs.customerReference.photo-ui-fixture-reference"]
        XCTAssertTrue(reference.waitForExistence(timeout: 10))
        tapWhenReady(reference)
        let useForNewOrder = app.buttons["designs.customerReference.useForNewOrder"]
        XCTAssertTrue(useForNewOrder.waitForExistence(timeout: 5))
        tapWhenReady(useForNewOrder)

        XCTAssertTrue(app.navigationBars["Add Order"].waitForExistence(timeout: 10))
        let designField = app.buttons["orders.form.design"]
        XCTAssertTrue(designField.waitForExistence(timeout: 5))
        XCTAssertTrue(designField.label.contains("Customer Reference"))
        tapWhenReady(designField)

        let currentReference = app.descendants(matching: .any)[
            "orders.designSelection.customerReference"
        ]
        XCTAssertTrue(currentReference.waitForExistence(timeout: 5))
        XCTAssertTrue(currentReference.isSelected)
        XCTAssertFalse(app.buttons["orders.designSelection.none"].isSelected)
    }

    func testDesignDetailSupportsZoomControlsAndAdjacentSwipe() throws {
        let app = makeApp(initialDestination: "designs")
        app.launchEnvironment["CLOUDBAKE_SEED_DESIGN_GALLERY_FIXTURE"] = "1"
        app.launch()

        let floralFilter = app.buttons["#Floral"]
        XCTAssertTrue(floralFilter.waitForExistence(timeout: 10))
        tapWhenReady(floralFilter)

        let firstDesign = app.buttons["designs.item.design-ui-gallery-first"]
        XCTAssertTrue(firstDesign.waitForExistence(timeout: 10))
        tapWhenReady(firstDesign)

        let zoomControls = app.descendants(matching: .any)["designs.preview.zoomControls"]
        XCTAssertTrue(zoomControls.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Zoom In"].exists)
        XCTAssertTrue(app.buttons["Zoom Out"].exists)
        XCTAssertTrue(app.buttons["Reset Zoom"].exists)

        let photo = app.descendants(matching: .any)["designs.preview.photo"]
        XCTAssertTrue(photo.waitForExistence(timeout: 5))
        XCTAssertTrue(String(describing: photo.value).contains("100 percent"))
        tapWhenReady(app.buttons["Zoom In"])
        XCTAssertTrue(String(describing: photo.value).contains("150 percent"))
        tapWhenReady(app.buttons["Reset Zoom"])

        XCTAssertFalse(app.buttons["Previous Design"].isEnabled)
        tapWhenReady(app.buttons["Next Design"])

        XCTAssertTrue(app.navigationBars["Second Gallery Cake"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Next Design"].isEnabled)
        tapWhenReady(app.buttons["Previous Design"])
        XCTAssertTrue(app.navigationBars["First Gallery Cake"].waitForExistence(timeout: 5))
    }

    func testDesignLandingCanScrollFromBottomBackToTop() throws {
        let app = makeApp(initialDestination: "designs")
        app.launchEnvironment["CLOUDBAKE_SEED_CAKE_DESIGN_FIXTURE"] = "1"
        app.launchEnvironment["CLOUDBAKE_SEED_ORDER_PHOTO_FIXTURE"] = "1"
        app.launch()

        let internetSection = app.staticTexts["designs.internetInspiration.title"]
        scrollToHittable(internetSection, in: app, timeout: 10)
        XCTAssertTrue(internetSection.isHittable)

        for _ in 0..<4 { app.swipeDown() }

        let search = app.descendants(matching: .any)["designs.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        XCTAssertTrue(search.isHittable)
    }

    func testSettingsShowsInventoryCSVActions() throws {
        let app = makeApp()
        app.launch()

        openDashboardDestination("Settings", in: app)

        XCTAssertTrue(app.buttons["settings.currency"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["settings.inventory.import"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["settings.inventory.export"].waitForExistence(timeout: 5))
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
        XCTAssertEqual(draftStatusOption.value as? String, "Selected")
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
        XCTAssertTrue(app.staticTexts["orders.detail.designPhotoReference"].label.contains("photo-ui-fixture-final"))
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

    func testOrderCanCreateAndLinkNewCustomerFromSelection() throws {
        let app = makeApp()
        let transitionTimeout: TimeInterval = 25
        app.launch()

        openDashboardDestination("Orders", in: app, timeout: transitionTimeout)
        assertScreenVisible("screen.orders", in: app, timeout: transitionTimeout)
        tapWhenReady(app.buttons["orders.add"], timeout: transitionTimeout)
        XCTAssertTrue(app.navigationBars["Add Order"].waitForExistence(timeout: transitionTimeout))

        typeText("Chocolate Celebration", into: app.textFields["orders.form.title"], timeout: transitionTimeout)
        dismissKeyboard(in: app)

        let customerRecordButton = app.buttons["orders.form.customerRecord"]
        scrollToHittable(customerRecordButton, in: app, timeout: transitionTimeout)
        tapWhenReady(customerRecordButton, timeout: transitionTimeout)
        XCTAssertTrue(app.navigationBars["Customer Record"].waitForExistence(timeout: transitionTimeout))

        tapWhenReady(app.buttons["orders.customerSelection.newCustomer"], timeout: transitionTimeout)
        tapWhenReady(app.buttons["orders.customerSelection.add.manual"], timeout: transitionTimeout)
        XCTAssertTrue(app.navigationBars["Add Customer"].waitForExistence(timeout: transitionTimeout))
        typeText("Maya", into: app.textFields["customers.form.name"], timeout: transitionTimeout)
        dismissKeyboard(in: app)
        typeText("5550303", into: app.textFields["customers.form.phone"], timeout: transitionTimeout)
        dismissKeyboard(in: app)
        tapWhenReady(app.buttons["customers.form.save"], timeout: transitionTimeout)

        XCTAssertTrue(app.navigationBars["Add Order"].waitForExistence(timeout: transitionTimeout))
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
        assertExistsAfterScrolling(app.staticTexts["orders.detail.designPhotoReference"], in: app, timeout: transitionTimeout)
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
        tapExisting(app.buttons["orders.detail.confirmInventoryDeduction"], timeout: transitionTimeout)
        let readyStatus = app.staticTexts["orders.detail.status"]
        XCTAssertTrue(readyStatus.waitForExistence(timeout: transitionTimeout))
        XCTAssertTrue(readyStatus.label.contains("Ready"))
        app.buttons["orders.detail.done"].tap()
        returnToDashboard(in: app)

        openDashboardDestination("Inventory", in: app, timeout: transitionTimeout)
        XCTAssertTrue(app.staticTexts["Current Quantity: 500 g"].waitForExistence(timeout: transitionTimeout))
    }

    func testOrderCalendarViewShowsOrders() throws {
        let app = makeApp()
        let transitionTimeout: TimeInterval = 15
        app.launch()

        openDashboardDestination("Orders", in: app)
        assertScreenVisible("screen.orders", in: app, timeout: transitionTimeout)
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
