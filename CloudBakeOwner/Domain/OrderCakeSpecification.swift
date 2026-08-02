import Foundation

enum OrderCakeRequirementField: String, CaseIterable {
    case occasion
    case size
    case shape
    case tiers
    case spongeFlavour = "sponge_flavour"
    case filling
    case frosting
    case colourPalette = "colour_palette"
    case theme
    case topperRequirements = "topper_requirements"
    case candlesAndAccessories = "candles_and_accessories"
    case packaging
}

struct OrderCakeSpecification: Equatable {
    static let empty = OrderCakeSpecification()
    static let newOrderDefaults = OrderCakeSpecification(
        topperRequirements: "None",
        candlesAndAccessories: "None",
        packaging: "Standard Box"
    )

    let occasion: String?
    let servings: Int?
    let size: String?
    let weightKilograms: Decimal?
    let shape: String?
    let tiers: String?
    let spongeFlavour: String?
    let filling: String?
    let frosting: String?
    let colourPalette: String?
    let theme: String?
    let topperRequirements: String?
    let candlesAndAccessories: String?
    let packaging: String?

    init(
        occasion: String? = nil,
        servings: Int? = nil,
        size: String? = nil,
        weightKilograms: Decimal? = nil,
        shape: String? = nil,
        tiers: String? = nil,
        spongeFlavour: String? = nil,
        filling: String? = nil,
        frosting: String? = nil,
        colourPalette: String? = nil,
        theme: String? = nil,
        topperRequirements: String? = nil,
        candlesAndAccessories: String? = nil,
        packaging: String? = nil
    ) {
        self.occasion = Self.optionalText(occasion)
        self.servings = servings.flatMap { $0 > 0 ? $0 : nil }
        self.size = Self.optionalText(size)
        self.weightKilograms = weightKilograms.flatMap { $0 > 0 ? $0 : nil }
        self.shape = Self.optionalText(shape)
        self.tiers = Self.optionalText(tiers)
        self.spongeFlavour = Self.optionalText(spongeFlavour)
        self.filling = Self.optionalText(filling)
        self.frosting = Self.optionalText(frosting)
        self.colourPalette = Self.optionalText(colourPalette)
        self.theme = Self.optionalText(theme)
        self.topperRequirements = Self.optionalText(topperRequirements)
        self.candlesAndAccessories = Self.optionalText(candlesAndAccessories)
        self.packaging = Self.optionalText(packaging)
    }

    var summary: String? {
        let occasionPhrase = meaningfulText(occasion).map { "\($0) cake" } ?? "Cake"
        var opening = occasionPhrase

        let capacity = [
            servings.map { "\($0) servings" },
            weightKilograms.map { "\(Self.decimalText($0)) kg" },
        ].compactMap { $0 }
        if capacity.count == 1 {
            opening += " for \(capacity[0])"
        } else if capacity.count == 2 {
            opening += " for \(capacity[0]) (\(capacity[1]))"
        }

        var clauses: [String] = [opening]
        let physicalForm = [
            meaningfulText(size),
            meaningfulText(shape)?.lowercased(),
            meaningfulText(tiers).map { "\($0) \($0 == "1" ? "tier" : "tiers")" },
        ].compactMap { $0 }
        if !physicalForm.isEmpty {
            clauses.append(physicalForm.joined(separator: ", "))
        }

        let flavours = [
            meaningfulText(spongeFlavour).map { "\($0.lowercased()) sponge" },
            meaningfulText(filling).map { "\($0.lowercased()) filling" },
            meaningfulText(frosting).map { "\($0.lowercased()) frosting" },
        ].compactMap { $0 }
        if !flavours.isEmpty {
            clauses.append("with \(Self.englishList(flavours))")
        }

        let visualDirection = [
            meaningfulText(colourPalette).map { "\($0) palette" },
            meaningfulText(theme).map { "\($0) theme" },
        ].compactMap { $0 }
        if !visualDirection.isEmpty {
            clauses.append(Self.englishList(visualDirection))
        }

        let extras = [
            meaningfulText(topperRequirements),
            meaningfulText(candlesAndAccessories),
        ].compactMap { $0 }
        if !extras.isEmpty {
            clauses.append(Self.englishList(extras))
        }

        if let packaging = meaningfulText(packaging) {
            clauses.append("packed in \(packaging.lowercased())")
        }

        guard clauses.count > 1 || occasionPhrase != "Cake" else { return nil }
        return clauses.joined(separator: "; ") + "."
    }

    var reusableChoiceValues: [(field: OrderCakeRequirementField, value: String)] {
        [
            (.occasion, occasion),
            (.size, size),
            (.shape, shape),
            (.tiers, tiers),
            (.spongeFlavour, spongeFlavour),
            (.filling, filling),
            (.frosting, frosting),
            (.colourPalette, colourPalette),
            (.theme, theme),
            (.topperRequirements, topperRequirements),
            (.candlesAndAccessories, candlesAndAccessories),
            (.packaging, packaging),
        ].compactMap { field, value in
            guard let value = Self.optionalText(value), !Self.isBuiltInChoice(value, for: field) else {
                return nil
            }
            return (field, value)
        }
    }

    static func suggestedWeight(forServings servings: Int) -> Decimal? {
        guard servings > 0 else { return nil }
        return rounded(Decimal(servings) / 14, scale: 1)
    }

    static func suggestedServings(forWeightKilograms weight: Decimal) -> Int? {
        guard weight > 0 else { return nil }
        return NSDecimalNumber(decimal: rounded(weight * 14, scale: 0)).intValue
    }

    static func mergedChoices(defaults: [String], saved: [String], current: String? = nil) -> [String] {
        var seen: Set<String> = []
        return (defaults + saved + [current].compactMap { $0 }).compactMap { value in
            guard let normalized = optionalText(value) else { return nil }
            let key = normalized.folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: .current
            )
            guard seen.insert(key).inserted else { return nil }
            return normalized
        }
    }

    private func meaningfulText(_ value: String?) -> String? {
        guard let value = Self.optionalText(value), value.caseInsensitiveCompare("None") != .orderedSame else {
            return nil
        }
        return value
    }

    private static func optionalText(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func isBuiltInChoice(
        _ value: String,
        for field: OrderCakeRequirementField
    ) -> Bool {
        let builtInChoices: [OrderCakeRequirementField: [String]] = [
            .occasion: ["Birthday", "Wedding", "Anniversary", "Baby Shower", "Celebration"],
            .size: ["4 in", "6 in", "8 in", "10 in", "12 in"],
            .shape: ["Circle", "Square", "Oval"],
            .tiers: ["1", "2", "3"],
            .spongeFlavour: ["Vanilla", "Chocolate"],
            .filling: ["Buttercream", "Chocolate Ganache", "Fruit"],
            .frosting: ["Buttercream", "Whipped Cream", "Ganache", "Fondant"],
            .topperRequirements: ["None"],
            .candlesAndAccessories: ["None"],
            .packaging: ["Standard Box", "Tall Box", "Window Box"],
        ]
        return builtInChoices[field, default: []].contains {
            $0.caseInsensitiveCompare(value) == .orderedSame
        }
    }

    private static func rounded(_ value: Decimal, scale: Int) -> Decimal {
        var input = value
        var output = Decimal()
        NSDecimalRound(&output, &input, scale, .plain)
        return output
    }

    private static func decimalText(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }

    private static func englishList(_ values: [String]) -> String {
        switch values.count {
        case 0:
            return ""
        case 1:
            return values[0]
        case 2:
            return values.joined(separator: " and ")
        default:
            return values.dropLast().joined(separator: ", ") + ", and " + (values.last ?? "")
        }
    }
}
