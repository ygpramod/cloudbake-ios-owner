import GRDB

enum AppDatabaseMigrations {
    static func makeMigrator() -> DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("0001_create_health_checks") { db in
            try db.create(table: "app_health_checks") { table in
                table.column("id", .text).primaryKey()
                table.column("note", .text).notNull()
                table.column("created_at_unix_time", .double).notNull()
            }
        }

        return migrator
    }
}
