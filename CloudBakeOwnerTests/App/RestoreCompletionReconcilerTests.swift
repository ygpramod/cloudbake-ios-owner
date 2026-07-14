import XCTest
@testable import CloudBakeOwner

@MainActor
final class RestoreCompletionReconcilerTests: XCTestCase {
    func testReconciliationRefreshesRemindersBeforeResumingBackup() async {
        var events: [String] = []
        let reconciler = RestoreCompletionReconciler(
            refreshReminders: {
                events.append("reminders")
            },
            resumeBackup: {
                events.append("backup")
            }
        )

        await reconciler.reconcile()

        XCTAssertEqual(events, ["reminders", "backup"])
    }
}
