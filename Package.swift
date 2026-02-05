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
            url: "https://github.com/paylisher/PAYLISHER-FW-IOS/releases/download/1.7.1/Paylisher.xcframework.zip",
            checksum: "5afee0b056d25028f7507f316fe0b673001dfe57cc15ec9d7386af3abcdc9015"
        )
    ]
)
