// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VoiceCalendar",
    platforms: [.iOS("17.0")],
    targets: [
        .executableTarget(
            name: "VoiceCalendar",
            path: "."
        )
    ]
)
