// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SitCheck",
    defaultLocalization: "ko",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "SitCheck", targets: ["SitCheck"]),
        .library(name: "SitCheckCore", targets: ["SitCheckCore"]),
    ],
    targets: [
        // UI·OS와 무관한 순수 로직 (착석 추적, 처방, 알림 판정, 저장)
        .target(
            name: "SitCheckCore",
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        // macOS 메뉴바 앱 (SwiftUI MenuBarExtra + NSPanel)
        .executableTarget(
            name: "SitCheck",
            dependencies: ["SitCheckCore"]
        ),
        .testTarget(
            name: "SitCheckCoreTests",
            dependencies: ["SitCheckCore"]
        ),
    ]
)
