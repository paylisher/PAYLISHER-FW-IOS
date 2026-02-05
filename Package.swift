// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "Paylisher",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "Paylisher",
            targets: ["Paylisher"]
        ),
    ],
    targets: [
        .binaryTarget(
            name: "Paylisher",
            url: "https://github.com/paylisher/PAYLISHER-FW-IOS/releases/download/1.6.0/Paylisher.xcframework.zip",
            checksum: "1886913f12cdd9cd8fbd74bf35cb087ec4d3b0d38eda7db3a2b696eeee394adf"
        )
    ]
)
