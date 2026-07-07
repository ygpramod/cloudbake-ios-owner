import Foundation
import GRDB

extension GRDBCoreDataRepository {
    func save(_ rule: PricingRule) throws {
        try writer.write { db in
            try db.execute(
                sql: """
                    INSERT OR REPLACE INTO pricing_rules
                    (id, name, kind, amount_decimal, currency_code, created_at_unix_time, updated_at_unix_time)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                    """,
                arguments: arguments([
                    rule.id,
                    rule.name,
                    rule.kind.rawValue,
                    NSDecimalNumber(decimal: rule.amount).stringValue,
                    rule.currencyCode,
                    rule.createdAt.timeIntervalSince1970,
                    rule.updatedAt.timeIntervalSince1970
                ])
            )
        }
    }

    func fetchPricingRule(id: String) throws -> PricingRule? {
        try writer.read { db in
            guard let row = try Row.fetchOne(db, sql: "SELECT * FROM pricing_rules WHERE id = ?", arguments: [id]),
                  let kind = PricingRuleKind(rawValue: row["kind"]),
                  let amount = Decimal(string: row["amount_decimal"]) else {
                return nil
            }

            return PricingRule(
                id: row["id"],
                name: row["name"],
                kind: kind,
                amount: amount,
                currencyCode: row["currency_code"],
                createdAt: date(row["created_at_unix_time"]),
                updatedAt: date(row["updated_at_unix_time"])
            )
        }
    }
}
