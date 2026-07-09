import Foundation
import GRDB

extension GRDBCoreDataRepository {
    func save(_ customer: Customer) throws {
        try writer.write { db in
            try db.execute(
                sql: """
                    INSERT OR REPLACE INTO customers
                    (id, name, phone, email, address, likes, dislikes, allergies, dietary_restrictions, notes, created_at_unix_time, updated_at_unix_time)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                arguments: arguments([
                    customer.id,
                    customer.name,
                    customer.phone,
                    customer.email,
                    customer.address,
                    customer.likes,
                    customer.dislikes,
                    customer.allergies,
                    customer.dietaryRestrictions,
                    customer.notes,
                    customer.createdAt.timeIntervalSince1970,
                    customer.updatedAt.timeIntervalSince1970
                ])
            )
        }
    }

    func fetchCustomer(id: String) throws -> Customer? {
        try writer.read { db in
            guard let row = try Row.fetchOne(db, sql: "SELECT * FROM customers WHERE id = ?", arguments: [id]) else {
                return nil
            }

            return customer(from: row)
        }
    }

    func fetchCustomers() throws -> [Customer] {
        try writer.read { db in
            try Row.fetchAll(
                db,
                sql: "SELECT * FROM customers ORDER BY lower(name), name"
            ).map(customer)
        }
    }

    func deleteCustomer(id: String) throws {
        try writer.write { db in
            try db.execute(
                sql: "UPDATE orders SET customer_id = NULL WHERE customer_id = ?",
                arguments: [id]
            )
            try db.execute(
                sql: "DELETE FROM customers WHERE id = ?",
                arguments: [id]
            )
        }
    }

    func save(_ importantDate: CustomerImportantDate) throws {
        try writer.write { db in
            try db.execute(
                sql: """
                    INSERT OR REPLACE INTO customer_important_dates
                    (id, customer_id, label, date_unix_time, created_at_unix_time, updated_at_unix_time)
                    VALUES (?, ?, ?, ?, ?, ?)
                    """,
                arguments: arguments([
                    importantDate.id,
                    importantDate.customerId,
                    importantDate.label,
                    importantDate.date.timeIntervalSince1970,
                    importantDate.createdAt.timeIntervalSince1970,
                    importantDate.updatedAt.timeIntervalSince1970
                ])
            )
        }
    }

    func fetchCustomerImportantDates(customerId: String) throws -> [CustomerImportantDate] {
        try writer.read { db in
            try Row.fetchAll(
                db,
                sql: """
                    SELECT * FROM customer_important_dates
                    WHERE customer_id = ?
                    ORDER BY date_unix_time ASC, lower(label), label
                    """,
                arguments: [customerId]
            ).map(customerImportantDate)
        }
    }
}
