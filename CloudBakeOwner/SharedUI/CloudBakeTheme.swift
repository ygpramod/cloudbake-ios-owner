import SwiftUI
import UIKit

enum CloudBakeTheme {
    enum ColorToken {
        static let appBackground = Color.cloudBakeBlush
        static let appBackgroundWash = Color.white
        static let surface = Color.white
        static let primaryAction = Color.cloudBakePink
        static let secondaryAction = Color.cloudBakePurple
        static let inventoryAccent = Color.cloudBakeOrange
        static let recipeAccent = Color.cloudBakeMint
        static let customerAccent = Color.cloudBakeTeal
        static let ownerAccent = Color.cloudBakeBrown
        static let destructive = Color.red
        static let success = Color.green
    }

    enum Typography {
        static let screenTitle = Font.system(size: 28, weight: .heavy, design: .rounded)
        static let brandTitle = Font.system(size: 32, weight: .heavy, design: .serif)
        static let metricValue = Font.system(size: 28, weight: .bold, design: .rounded)
        static let sectionTitle = Font.headline.weight(.semibold)
        static let rowTitle = Font.headline.weight(.semibold)
        static let rowDetail = Font.footnote
        static let metadata = Font.caption
    }

    enum Spacing {
        static let screenHorizontal: CGFloat = 24
        static let detailHorizontal: CGFloat = 22
        static let screenTop: CGFloat = 18
        static let section: CGFloat = 24
        static let sectionContent: CGFloat = 14
        static let rowContent: CGFloat = 18
        static let cardPadding: CGFloat = 20
        static let compactControl: CGFloat = 12
        static let bottomNavigationHeight: CGFloat = 104
    }

    enum Shape {
        static let cardRadius: CGFloat = 24
        static let largeCardRadius: CGFloat = 28
        static let bannerRadius: CGFloat = 18
        static let iconRadius: CGFloat = 15
    }

    enum Elevation {
        static let softShadow = Color.black.opacity(0.08)
        static let softRadius: CGFloat = 18
        static let softYOffset: CGFloat = 8
        static let controlShadow = Color.black.opacity(0.06)
        static let controlRadius: CGFloat = 12
        static let controlYOffset: CGFloat = 6
    }
}

