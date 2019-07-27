// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "Daisy",
    products: [
        .library(name: "Daisy", targets: ["Daisy"]),
    ],
    targets: [
        .target(name: "Daisy"),
        .testTarget(name: "DaisyTests", dependencies: ["Daisy"])
    ]
)
