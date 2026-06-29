import Foundation
import GRDB

struct HealthCheckEntry: Equatable {
    let id: String
    let note: String
    let createdAt: Date
}

protocol HealthCheckRepository {
    func save(_ entry: HealthCheckEntry) throws
    func fetch(id: String) throws -> HealthCheckEntry?
}

final class GRDBHealthCheckRepository: HealthCheckRepository {
    private let writer: any DatabaseWriter

    init(writer: any DatabaseWriter) {
        self.writer = writer
    }

    func save(_ entry: HealthCheckEntry) throws {
        try writer.write { db in
            try db.execute(
                sql: """
                    INSERT OR REPLACE INTO app_health_checks (id, note, created_at_unix_time)
                    VALUES (?, ?, ?)
                    """,
                arguments: StatementArguments([
                    entry.id,
                    entry.note,
                    entry.createdAt.timeIntervalSince1970
                ] as [(any DatabaseValueConvertible)?])
            )
        }
    }

    func fetch(id: String) throws -> HealthCheckEntry? {
        try writer.read { db in
            let row = try Row.fetchOne(
                db,
                sql: """
                    SELECT id, note, created_at_unix_time
                    FROM app_health_checks
                    WHERE id = ?
                    """,
                arguments: [id]
            )

            guard let row else {
                return nil
            }
            let createdAtUnixTime: Double = row["created_at_unix_time"]

            return HealthCheckEntry(
                id: row["id"],
                note: row["note"],
                createdAt: Date(timeIntervalSince1970: createdAtUnixTime)
            )
        }
    }
}
