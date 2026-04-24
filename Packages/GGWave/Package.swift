// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GGWave",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "GGWave", targets: ["GGWave"]),
    ],
    targets: [
        // C/C++ target wrapping real ggwave sources from
        // https://github.com/ggerganov/ggwave
        .target(
            name: "CGGWave",
            path: "Sources/CGGWave",
            publicHeadersPath: "include",
            cxxSettings: [
                .headerSearchPath("include"),
                .headerSearchPath("."),
                .define("GGWAVE_SHARED", to: "0"),
            ],
            linkerSettings: [
                .linkedFramework("Accelerate"),
            ]
        ),
        // Swift wrapper — uses only the C API from CGGWave.h
        .target(
            name: "GGWave",
            dependencies: ["CGGWave"],
            path: "Sources/GGWave"
        ),
    ],
    cxxLanguageStandard: .cxx17
)
