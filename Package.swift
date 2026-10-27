// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "CalendarClaimKit",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9)
    ],
    products: [
        .library(name: "CalendarClaimKit", targets: ["CalendarClaimKit"]),
        .executable(name: "CalendarClaimDemo", targets: ["CalendarClaimDemo"])
    ],
    targets: [
        .target(name: "CalendarClaimKit"),
        .executableTarget(
            name: "CalendarClaimDemo",
            dependencies: ["CalendarClaimKit"]
        ),
        .testTarget(
            name: "CalendarClaimKitTests",
            dependencies: ["CalendarClaimKit"]
        )
    ],
    swiftLanguageModes: [.v6]
)
