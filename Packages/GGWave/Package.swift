// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GGWave",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "GGWave", targets: ["GGWave"]),
    ],
    targets: [
        // C/C++ target wrapping ggwave sources
        // After cloning: cp /tmp/ggwave/include/ggwave/ggwave.h Sources/CGGWave/include/
        //                cp /tmp/ggwave/src/ggwave.cpp Sources/CGGWave/
        //                cp /tmp/ggwave/src/ggwave-common.cpp Sources/CGGWave/
        .target(
            name: "CGGWave",
            path: "Sources/CGGWave",
            publicHeadersPath: "include",
            cxxSettings: [
                .headerSearchPath("include"),
                .define("GGWAVE_SHARED", to: "0"),
            ],
            linkerSettings: [
                .linkedFramework("Accelerate"),
            ]
        ),
        // Swift wrapper
        .target(
            name: "GGWave",
            dependencies: ["CGGWave"],
            path: "Sources/GGWave",
            swiftSettings: [
                .interoperabilityMode(.Cxx),
            ]
        ),
    ],
    cxxLanguageStandard: .cxx17
)
