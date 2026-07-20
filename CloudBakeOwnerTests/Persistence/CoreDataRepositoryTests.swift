import Foundation
@testable import CloudBakeOwner

struct TestTimestamps {
    let createdAt: Date
    let updatedAt: Date
}

func makeSequentialIdProvider(_ ids: [String]) -> () -> String {
    var remainingIds = ids
    return {
        guard !remainingIds.isEmpty else {
            return "unexpected-transaction-id"
        }

        return remainingIds.removeFirst()
    }
}
