import XCTest

extension CloudBakeOwnerUITests {
    func testBackupNotificationColdLaunchOpensExpandedBackupSettings() {
        let app = makeApp()
        app.launchEnvironment["CLOUDBAKE_TEST_NOTIFICATION_DESTINATION"] = "backup-settings"
        app.launch()

        assertScreenVisible("screen.settings", in: app, timeout: 10)
        XCTAssertTrue(app.switches["settings.backup.weeklyReminder"].waitForExistence(timeout: 5))
    }

    func testFirstLaunchIntroductionSupportsNextAndSkip() {
        let app = makeApp()
        app.launchEnvironment["CLOUDBAKE_TEST_INTRODUCTION"] = "1"
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["introduction.page.home"].waitForExistence(timeout: 10))
        tapWhenReady(app.buttons["Next"])
        XCTAssertTrue(app.descendants(matching: .any)["introduction.page.orders"].waitForExistence(timeout: 5))
        tapWhenReady(app.buttons["Skip"])
        assertDashboardVisible(in: app)
    }

    func testSettingsOpensHelpGuideAndReplaysIntroduction() {
        let app = makeApp()
        app.launch()

        openDashboardDestination("Settings", in: app)
        let helpButton = app.buttons["settings.helpGuide"]
        scrollToVisible(helpButton, in: app)
        tapWhenReady(helpButton)
        assertScreenVisible("screen.helpGuide", in: app)
        tapWhenReady(app.buttons["help.viewIntroduction"])
        XCTAssertTrue(app.descendants(matching: .any)["introduction.page.home"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["bottom.navigation.more"].isHittable)
        for pageID in ["orders", "inventory", "library", "backup"] {
            tapWhenReady(app.buttons["Next"])
            XCTAssertTrue(app.descendants(matching: .any)["introduction.page.\(pageID)"].waitForExistence(timeout: 5))
        }
        tapWhenReady(app.buttons["Get Started"])
        assertScreenVisible("screen.helpGuide", in: app)
    }

    func testSettingsOpensPrivacyPolicy() {
        let app = makeApp()
        app.launch()

        openDashboardDestination("Settings", in: app)
        let settingsScroll = app.scrollViews["screen.settings"]
        XCTAssertTrue(settingsScroll.waitForExistence(timeout: 5))
        tapScrollableAction(
            app.buttons["settings.privacyPolicy"],
            in: settingsScroll,
            waitingFor: app.descendants(matching: .any)["screen.privacyPolicy"],
            in: app
        )
        XCTAssertTrue(app.buttons["privacy.onlinePolicy"].waitForExistence(timeout: 5))
    }

    func testSettingsSavesOrderReminderDefaults() {
        let app = makeApp(initialDestination: "settings")
        app.launch()

        let settingsScroll = app.scrollViews["screen.settings"]
        XCTAssertTrue(settingsScroll.waitForExistence(timeout: 5))
        let reminderSettings = app.buttons["settings.orderReminders"]
        tapScrollableAction(
            reminderSettings,
            in: settingsScroll,
            waitingFor: app.descendants(matching: .any)[
                "screen.settings.orderReminders"
            ],
            in: app
        )

        XCTAssertEqual(
            app.textFields["settings.orderReminders.dayOffsets"].value as? String,
            "3, 2, 1"
        )
        XCTAssertEqual(
            app.switches["settings.orderReminders.dueTime"].value as? String,
            "1"
        )
        let reminderSave = app.buttons["settings.orderReminders.save"]
        positionScrollableElementForInteraction(
            reminderSave,
            in: app.scrollViews["screen.settings.orderReminders"],
            app: app
        )
        reminderSave.coordinate(
            withNormalizedOffset: CGVector(dx: 0.12, dy: 0.5)
        ).tap()
        XCTAssertTrue(
            app.staticTexts["settings.orderReminders.status"]
                .waitForExistence(timeout: 5)
        )

        let paymentTime = app.datePickers["settings.paymentReminders.time"]
        scrollToVisible(paymentTime, in: app)
        XCTAssertTrue(paymentTime.exists)
        let paymentSave = app.buttons["settings.paymentReminders.save"]
        let paymentStatus = app.staticTexts["settings.paymentReminders.status"]
        positionScrollableElementForInteraction(
            paymentSave,
            in: app.scrollViews["screen.settings.orderReminders"],
            app: app
        )
        paymentSave.coordinate(
            withNormalizedOffset: CGVector(dx: 0.12, dy: 0.5)
        ).tap()
        XCTAssertTrue(paymentStatus.waitForExistence(timeout: 5))
    }

    func testSettingsShowsInventoryCSVActions() throws {
        let app = makeApp()
        app.launch()

        openDashboardDestination("Settings", in: app)

        XCTAssertTrue(app.buttons["settings.currency"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["settings.logo.choose"].waitForExistence(timeout: 5))
        let settingsScroll = expandSettingsSection(
            "settings.dataManagement.disclosure",
            revealing: app.buttons["settings.inventory.import"],
            in: app
        )
        XCTAssertTrue(app.buttons["settings.inventory.import"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["settings.inventory.export"].waitForExistence(timeout: 5))
        scrollToHittable(
            app.buttons["settings.recipes.import"],
            in: app,
            scrollContainer: settingsScroll
        )
        XCTAssertTrue(app.buttons["settings.recipes.export"].exists)
    }

    func testInventoryCSVExportPresentsDestinationPicker() throws {
        let app = makeApp()
        app.launch()

        openDashboardDestination("Settings", in: app)
        let settingsScroll = expandSettingsSection(
            "settings.dataManagement.disclosure",
            revealing: app.buttons["settings.inventory.export"],
            in: app
        )
        let exportButton = app.buttons["settings.inventory.export"]
        scrollToVisible(exportButton, in: app, scrollContainer: settingsScroll)
        tapWhenReady(exportButton)
        let confirmationTitle = app.staticTexts["Export Inventory CSV?"]
        if !confirmationTitle.waitForExistence(timeout: 10) {
            XCTFail("Inventory export confirmation did not appear. Hierarchy: \(app.debugDescription)")
        }
        tapWhenReady(nativeDialogAction(labeled: "Create Export", in: app))

        let exporter = app.descendants(matching: .any)["settings.fileExporter"]
        if !exporter.waitForExistence(timeout: 10) {
            XCTFail("Inventory exporter did not appear. Hierarchy: \(app.debugDescription)")
        }
    }

    func testInventoryCSVImportPresentsFilePicker() throws {
        let app = makeApp()
        app.launch()

        openDashboardDestination("Settings", in: app)
        let importButton = app.buttons["settings.inventory.import"]
        let confirmationTitle = app.staticTexts["Import Inventory CSV?"]
        let settingsScroll = expandSettingsSection(
            "settings.dataManagement.disclosure",
            revealing: importButton,
            in: app
        )
        tapScrollableAction(
            importButton,
            in: settingsScroll,
            waitingFor: confirmationTitle,
            in: app
        )
        tapWhenReady(nativeDialogAction(labeled: "Choose CSV File", in: app))

        let importer = app.descendants(matching: .any)["settings.fileImporter"]
        if !importer.waitForExistence(timeout: 10) {
            XCTFail("Inventory importer did not appear. Hierarchy: \(app.debugDescription)")
        }
    }

    func testManualFullBackupPresentsDestinationPicker() throws {
        let app = makeApp()
        app.launch()

        openDashboardDestination("Settings", in: app)
        let settingsScroll = expandSettingsSection(
            "settings.backup.disclosure",
            revealing: app.switches["settings.backup.weeklyReminder"],
            in: app
        )
        XCTAssertTrue(app.switches["settings.backup.weeklyReminder"].waitForExistence(timeout: 5))
        scrollToHittable(
            app.buttons["settings.backup.create"],
            in: app,
            scrollContainer: settingsScroll
        )
        tapWhenReady(app.buttons["settings.backup.create"])
        XCTAssertTrue(app.staticTexts["Create Full Backup?"].waitForExistence(timeout: 5))
        tapWhenReady(
            nativeDialogAction(
                identifiedBy: "settings.backup.create.continue",
                in: app
            )
        )

        let exporter = app.descendants(matching: .any)["settings.fileExporter"]
        if !exporter.waitForExistence(timeout: 15) {
            XCTFail("Backup exporter did not appear. Hierarchy: \(app.debugDescription)")
        }
    }

    func testCloudBackupSettingsRequireCellularConfirmation() throws {
        let app = makeApp(initialDestination: "settings")
        app.launchEnvironment["CLOUDBAKE_TEST_CLOUD_BACKUP_SETTINGS"] = "1"
        app.launch()

        XCTAssertFalse(app.switches["settings.cloudBackup.enabled"].exists)
        let enabledSwitch = app.switches["settings.cloudBackup.enabled"]
        let settingsScroll = expandSettingsSection(
            "settings.backup.disclosure",
            revealing: enabledSwitch,
            in: app
        )
        XCTAssertTrue(app.staticTexts["settings.cloudBackup.status"].exists)

        let backUpNowButton = app.buttons["settings.cloudBackup.backUpNow"]
        tapScrollableAction(
            backUpNowButton,
            in: settingsScroll,
            waitingFor: app.staticTexts["Use Cellular Data?"],
            in: app
        )
        XCTAssertTrue(app.staticTexts["Use Cellular Data?"].exists)
        dismissNativeDialog(titled: "Use Cellular Data?", in: app)
    }

    func testCloudBackupNotificationsCanBeDisabled() throws {
        let app = makeApp(initialDestination: "settings")
        app.launchEnvironment["CLOUDBAKE_TEST_CLOUD_BACKUP_SETTINGS"] = "1"
        app.launch()

        let notificationsSwitch = app.switches["settings.cloudBackup.notifications"]
        let settingsScroll = expandSettingsSection(
            "settings.backup.disclosure",
            revealing: notificationsSwitch,
            in: app
        )
        XCTAssertTrue(app.staticTexts["Enabled"].waitForExistence(timeout: 10))
        expectation(
            for: NSPredicate(format: "value == %@", "1"),
            evaluatedWith: notificationsSwitch
        )
        waitForExpectations(timeout: 5)
        positionScrollableElementForInteraction(
            notificationsSwitch,
            in: settingsScroll,
            app: app
        )
        tapWhenReady(notificationsSwitch)

        expectation(
            for: NSPredicate(format: "value == %@", "0"),
            evaluatedWith: notificationsSwitch
        )
        waitForExpectations(timeout: 5)
    }

    func testCloudBackupUnavailablePhotoDecisionRequiresExplicitChoice() throws {
        let app = makeApp(initialDestination: "settings")
        app.launchEnvironment["CLOUDBAKE_TEST_CLOUD_BACKUP_SETTINGS"] = "1"
        app.launchEnvironment["CLOUDBAKE_TEST_CLOUD_BACKUP_PHOTO_DECISION"] = "1"
        app.launch()

        let backUpNowButton = app.buttons["settings.cloudBackup.backUpNow"]
        let settingsScroll = expandSettingsSection(
            "settings.backup.disclosure",
            revealing: backUpNowButton,
            in: app
        )
        let lastSuccess = app.descendants(matching: .any)[
            "settings.cloudBackup.lastSuccess"
        ]
        XCTAssertTrue(lastSuccess.waitForExistence(timeout: 5))
        let lastSuccessBeforeCancellation = lastSuccess.label
        tapScrollableAction(
            backUpNowButton,
            in: settingsScroll,
            waitingFor: app.staticTexts["Unavailable Photos"],
            in: app
        )
        XCTAssertTrue(app.staticTexts["Unavailable Photos"].exists)

        tapWhenReady(
            nativeDialogAction(
                identifiedBy: "settings.cloudBackup.photos.remove",
                in: app
            )
        )
        XCTAssertTrue(
            app.staticTexts["Remove Broken References?"].waitForExistence(timeout: 5)
        )

        dismissNativeDialog(titled: "Remove Broken References?", in: app)
        XCTAssertTrue(
            app.staticTexts["Unavailable Photos"].waitForNonExistence(timeout: 5)
        )
        XCTAssertEqual(lastSuccess.label, lastSuccessBeforeCancellation)

        tapWhenReady(backUpNowButton)
        XCTAssertTrue(app.staticTexts["Unavailable Photos"].waitForExistence(timeout: 5))
        tapWhenReady(
            nativeDialogAction(
                identifiedBy: "settings.cloudBackup.photos.remove",
                in: app
            )
        )
        XCTAssertTrue(app.staticTexts["Remove Broken References?"].waitForExistence(timeout: 5))
        tapWhenReady(
            nativeDialogAction(
                identifiedBy: "settings.cloudBackup.photos.remove.confirm",
                in: app
            )
        )
        let actionMessage = app.staticTexts[
            "settings.cloudBackup.actionMessage"
        ]
        XCTAssertTrue(actionMessage.waitForExistence(timeout: 5))
        XCTAssertEqual(
            actionMessage.label,
            "Cloud backup completed successfully."
        )

        tapWhenReady(backUpNowButton)
        XCTAssertTrue(app.staticTexts["Unavailable Photos"].waitForExistence(timeout: 5))
        tapWhenReady(
            nativeDialogAction(
                identifiedBy: "settings.cloudBackup.photos.omit",
                in: app
            )
        )

        let omittedStatus =
            app.descendants(matching: .any)["settings.cloudBackup.omittedPhotos"]
        XCTAssertTrue(omittedStatus.waitForExistence(timeout: 5))
        XCTAssertTrue(
            omittedStatus.label.contains("Without 2 unavailable photos")
        )
        XCTAssertEqual(
            actionMessage.label,
            "Cloud backup completed without 2 unavailable photos."
        )

        let backupDisclosure = app.buttons["settings.backup.disclosure"]
        scrollToHittable(
            backupDisclosure,
            in: app,
            scrollContainer: settingsScroll
        )
        tapWhenReady(backupDisclosure)
        XCTAssertFalse(omittedStatus.exists)
        tapWhenReady(backupDisclosure)
        XCTAssertTrue(omittedStatus.waitForExistence(timeout: 5))
        XCTAssertTrue(
            omittedStatus.label.contains("Without 2 unavailable photos")
        )
    }

    func testCloudBackupDeniedPhotosAccessDoesNotOfferDestructiveChoices() throws {
        let app = makeApp(initialDestination: "settings")
        app.launchEnvironment["CLOUDBAKE_TEST_CLOUD_BACKUP_SETTINGS"] = "1"
        app.launchEnvironment[
            "CLOUDBAKE_TEST_CLOUD_BACKUP_PHOTOS_PERMISSION_DENIED"
        ] = "1"
        app.launch()

        let backUpNowButton = app.buttons["settings.cloudBackup.backUpNow"]
        let settingsScroll = expandSettingsSection(
            "settings.backup.disclosure",
            revealing: backUpNowButton,
            in: app
        )
        let actionMessage = app.staticTexts[
            "settings.cloudBackup.actionMessage"
        ]
        tapScrollableAction(
            backUpNowButton,
            in: settingsScroll,
            waitingFor: actionMessage,
            in: app
        )
        XCTAssertEqual(
            actionMessage.label,
            "Allow CloudBake full access to Photos in iPhone Settings, then try again."
        )
        XCTAssertFalse(app.buttons["settings.cloudBackup.photos.omit"].exists)
        XCTAssertFalse(app.buttons["settings.cloudBackup.photos.remove"].exists)
        XCTAssertFalse(app.buttons["settings.cloudBackup.photos.remove.confirm"].exists)
    }

    func testCloudBackupRequiresConfirmationBeforeUsingCurrentICloudAccount() throws {
        let app = makeApp(initialDestination: "settings")
        app.launchEnvironment["CLOUDBAKE_TEST_CLOUD_BACKUP_SETTINGS"] = "1"
        app.launchEnvironment["CLOUDBAKE_TEST_CLOUD_BACKUP_ACCOUNT_CONFIRMATION"] = "1"
        app.launch()

        let backUpNowButton = app.buttons["settings.cloudBackup.backUpNow"]
        let settingsScroll = expandSettingsSection(
            "settings.backup.disclosure",
            revealing: backUpNowButton,
            in: app
        )
        tapScrollableAction(
            backUpNowButton,
            in: settingsScroll,
            waitingFor: app.staticTexts["Use This iCloud Account?"],
            in: app
        )
        dismissNativeDialog(titled: "Use This iCloud Account?", in: app)
        tapWhenReady(backUpNowButton)
        XCTAssertTrue(app.staticTexts["Use This iCloud Account?"].waitForExistence(timeout: 5))
        tapWhenReady(
            nativeDialogAction(
                identifiedBy: "settings.cloudBackup.account.confirm",
                in: app
            )
        )
        XCTAssertTrue(app.staticTexts["settings.cloudBackup.status"].waitForExistence(timeout: 5))
    }

    func testCloudBackupDeletionRequiresConfirmationAndPreservesSettingsScreen() throws {
        let app = makeApp(initialDestination: "settings")
        app.launchEnvironment["CLOUDBAKE_TEST_CLOUD_BACKUP_SETTINGS"] = "1"
        app.launch()

        let deleteButton = app.buttons["settings.cloudBackup.delete"]
        let settingsScroll = expandSettingsSection(
            "settings.dataManagement.disclosure",
            revealing: deleteButton,
            in: app
        )
        tapScrollableAction(
            deleteButton,
            in: settingsScroll,
            waitingFor: app.staticTexts["Delete Cloud Backup?"],
            in: app
        )

        XCTAssertTrue(app.staticTexts["Delete Cloud Backup?"].waitForExistence(timeout: 5))
        dismissNativeDialog(titled: "Delete Cloud Backup?", in: app)
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5))

        tapScrollableAction(
            deleteButton,
            in: settingsScroll,
            waitingFor: app.staticTexts["Delete Cloud Backup?"],
            in: app
        )
        tapWhenReady(
            nativeDialogAction(
                identifiedBy: "settings.cloudBackup.delete.confirm",
                in: app
            )
        )
        XCTAssertTrue(
            app.staticTexts["settings.cloudBackup.delete.message"].waitForExistence(timeout: 5)
        )
    }

    func testCloudBackupDeletionFailureKeepsBackupDisabledAndRetryable() throws {
        let app = makeApp(initialDestination: "settings")
        app.launchEnvironment["CLOUDBAKE_TEST_CLOUD_BACKUP_SETTINGS"] = "1"
        app.launchEnvironment["CLOUDBAKE_TEST_CLOUD_BACKUP_DELETE_FAILURE"] = "1"
        app.launch()

        let settingsScroll = app.scrollViews["screen.settings"]
        XCTAssertTrue(settingsScroll.waitForExistence(timeout: 5))
        let deleteButton = app.buttons["settings.cloudBackup.delete"]
        tapScrollableAction(
            app.buttons["settings.dataManagement.disclosure"],
            in: settingsScroll,
            waitingFor: deleteButton,
            in: app
        )
        tapScrollableAction(
            deleteButton,
            in: settingsScroll,
            waitingFor: app.staticTexts["Delete Cloud Backup?"],
            in: app
        )
        tapWhenReady(
            nativeDialogAction(
                identifiedBy: "settings.cloudBackup.delete.confirm",
                in: app
            )
        )

        let message = app.staticTexts["settings.cloudBackup.delete.message"]
        XCTAssertTrue(message.waitForExistence(timeout: 5))
        XCTAssertTrue(message.label.contains("Backup remains off"))
        XCTAssertTrue(deleteButton.exists)
    }

    func testEmptyInstallationOffersRestoreOrStartFresh() throws {
        let app = makeApp()
        app.launchEnvironment["CLOUDBAKE_TEST_EMPTY_RESTORE"] = "1"
        app.launch()

        XCTAssertTrue(app.staticTexts["Restore Cloud Backup?"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            nativeDialogAction(
                labeled: "Restore Backup",
                in: app
            ).exists
        )
        let startFreshButton = nativeDialogAction(
            labeled: "Start Fresh",
            in: app
        )
        tapWhenReady(startFreshButton)

        XCTAssertTrue(startFreshButton.waitForNonExistence(timeout: 5))
        assertDashboardVisible(in: app)
    }

    func testEmptyInstallationRestoresCompatibleBackupOnWiFi() throws {
        let app = makeApp()
        app.launchEnvironment["CLOUDBAKE_TEST_EMPTY_RESTORE"] = "1"
        app.launch()

        XCTAssertTrue(app.staticTexts["Restore Cloud Backup?"].waitForExistence(timeout: 5))
        let restoreButton = nativeDialogAction(
            labeled: "Restore Backup",
            in: app
        )
        tapWhenReady(restoreButton)

        XCTAssertTrue(restoreButton.waitForNonExistence(timeout: 5))
        assertDashboardVisible(in: app)
    }

    func testCloudRestoreRequiresDestructiveCellularAndBrokenAssetChoices() throws {
        let app = makeApp(initialDestination: "settings")
        app.launchEnvironment["CLOUDBAKE_TEST_CLOUD_RESTORE_SETTINGS"] = "1"
        app.launchEnvironment["CLOUDBAKE_SEED_CUSTOMER_FIXTURE"] = "1"
        app.launch()

        assertScreenVisible("screen.settings", in: app)
        let settingsScroll = app.scrollViews["screen.settings"]
        let restoreButton = app.buttons["settings.cloudBackup.restore"]
        tapScrollableAction(
            app.buttons["settings.dataManagement.disclosure"],
            in: settingsScroll,
            waitingFor: restoreButton,
            in: app
        )
        tapScrollableAction(
            restoreButton,
            in: settingsScroll,
            waitingFor: app.staticTexts["Replace Local Data?"],
            in: app
        )

        XCTAssertTrue(app.staticTexts["Replace Local Data?"].waitForExistence(timeout: 5))
        tapWhenReady(
            nativeDialogAction(
                identifiedBy: "settings.cloudRestore.replace.confirm",
                in: app
            )
        )

        XCTAssertTrue(app.staticTexts["Use Cellular Data?"].waitForExistence(timeout: 5))
        tapWhenReady(
            nativeDialogAction(
                identifiedBy: "settings.cloudRestore.cellular.confirm",
                in: app
            )
        )

        XCTAssertTrue(app.staticTexts["Some Photos Are Unavailable"].waitForExistence(timeout: 5))
        tapWhenReady(
            nativeDialogAction(
                identifiedBy: "settings.cloudRestore.assets.remove",
                in: app
            )
        )

        XCTAssertTrue(
            app.staticTexts["settings.cloudRestore.message"].waitForExistence(timeout: 5)
        )
        XCTAssertEqual(
            app.staticTexts["settings.cloudRestore.message"].label,
            "Cloud backup restored successfully."
        )
    }

    func testCloudRestoreExplainsWhenAppUpdateIsRequired() throws {
        let app = makeApp(initialDestination: "settings")
        app.launchEnvironment["CLOUDBAKE_TEST_CLOUD_RESTORE_FAILURE"] = "update-required"
        app.launchEnvironment["CLOUDBAKE_SEED_CUSTOMER_FIXTURE"] = "1"
        app.launch()

        assertScreenVisible("screen.settings", in: app)
        let settingsScroll = app.scrollViews["screen.settings"]
        let restoreButton = app.buttons["settings.cloudBackup.restore"]
        let message = app.staticTexts["settings.cloudRestore.message"]
        tapScrollableAction(
            app.buttons["settings.dataManagement.disclosure"],
            in: settingsScroll,
            waitingFor: restoreButton,
            in: app
        )
        tapScrollableAction(
            restoreButton,
            in: settingsScroll,
            waitingFor: message,
            in: app
        )
        XCTAssertTrue(message.waitForExistence(timeout: 5))
        XCTAssertEqual(
            message.label,
            "Update CloudBake to version 2.0 or later before restoring this backup."
        )
    }

    func testCloudRestoreReportsSuccessfulRollbackAfterActivationFailure() throws {
        let app = makeApp(initialDestination: "settings")
        app.launchEnvironment["CLOUDBAKE_TEST_CLOUD_RESTORE_FAILURE"] = "rollback"
        app.launchEnvironment["CLOUDBAKE_SEED_CUSTOMER_FIXTURE"] = "1"
        app.launch()

        assertScreenVisible("screen.settings", in: app)
        let settingsScroll = app.scrollViews["screen.settings"]
        let restoreButton = app.buttons["settings.cloudBackup.restore"]
        tapScrollableAction(
            app.buttons["settings.dataManagement.disclosure"],
            in: settingsScroll,
            waitingFor: restoreButton,
            in: app
        )
        tapScrollableAction(
            restoreButton,
            in: settingsScroll,
            waitingFor: app.staticTexts["Replace Local Data?"],
            in: app
        )
        tapWhenReady(
            nativeDialogAction(
                identifiedBy: "settings.cloudRestore.replace.confirm",
                in: app
            )
        )

        let message = app.staticTexts["settings.cloudRestore.message"]
        XCTAssertTrue(message.waitForExistence(timeout: 5))
        XCTAssertEqual(
            message.label,
            "Restore failed, and CloudBake returned to your previous local data."
        )
    }

    func testCloudRestoreKeepsPromptAvailableAfterInvalidApproval() throws {
        let app = makeApp(initialDestination: "settings")
        app.launchEnvironment["CLOUDBAKE_TEST_CLOUD_RESTORE_FAILURE"] = "invalid-approval"
        app.launchEnvironment["CLOUDBAKE_SEED_CUSTOMER_FIXTURE"] = "1"
        app.launch()

        assertScreenVisible("screen.settings", in: app)
        let settingsScroll = app.scrollViews["screen.settings"]
        let restoreButton = app.buttons["settings.cloudBackup.restore"]
        tapScrollableAction(
            app.buttons["settings.dataManagement.disclosure"],
            in: settingsScroll,
            waitingFor: restoreButton,
            in: app
        )
        tapScrollableAction(
            restoreButton,
            in: settingsScroll,
            waitingFor: app.staticTexts["Replace Local Data?"],
            in: app
        )
        tapWhenReady(
            nativeDialogAction(
                identifiedBy: "settings.cloudRestore.replace.confirm",
                in: app
            )
        )

        XCTAssertTrue(
            app.staticTexts["Replace Local Data?"].waitForExistence(timeout: 5)
        )
        let retry = nativeDialogAction(
            identifiedBy: "settings.cloudRestore.replace.confirm",
            in: app
        )
        XCTAssertTrue(retry.waitForExistence(timeout: 5))
        XCTAssertTrue(retry.isHittable)
        dismissNativeDialog(titled: "Replace Local Data?", in: app)
    }

    func testCloudRestoreBlocksAppWhenRollbackCannotBeGuaranteed() throws {
        let app = makeApp(initialDestination: "settings")
        app.launchEnvironment["CLOUDBAKE_TEST_CLOUD_RESTORE_FAILURE"] = "recovery-required"
        app.launchEnvironment["CLOUDBAKE_SEED_CUSTOMER_FIXTURE"] = "1"
        app.launch()

        assertScreenVisible("screen.settings", in: app)
        let settingsScroll = app.scrollViews["screen.settings"]
        let restoreButton = app.buttons["settings.cloudBackup.restore"]
        tapScrollableAction(
            app.buttons["settings.dataManagement.disclosure"],
            in: settingsScroll,
            waitingFor: restoreButton,
            in: app
        )
        tapScrollableAction(
            restoreButton,
            in: settingsScroll,
            waitingFor: app.staticTexts["Replace Local Data?"],
            in: app
        )
        tapWhenReady(
            nativeDialogAction(
                identifiedBy: "settings.cloudRestore.replace.confirm",
                in: app
            )
        )

        XCTAssertTrue(
            app.staticTexts["Reopen CloudBake to Finish Recovery"].waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            app.staticTexts.matching(
                NSPredicate(
                    format: "label CONTAINS %@",
                    "stopped access to your data"
                )
            ).firstMatch.exists
        )
        XCTAssertFalse(app.buttons["bottom.navigation.dashboard"].isEnabled)
    }

}
