// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "CombineAction",
  platforms: [.iOS(.v13), .tvOS(.v13), .macOS(.v10_15)],
  products: [
    // Products define the executables and libraries a package produces, and make them visible to other packages.
    .library(
      name: "CombineAction",
      targets: ["CombineAction"]
    )
  ],
  dependencies: [
    .package(
      name: "CombineExt",
      url: "https://github.com/CombineCommunity/CombineExt",
      .upToNextMajor(from: "1.3.0"))
  ],
  targets: [
    .target(
      name: "CombineAction",
      dependencies: [
        "CombineExt"
      ]
    ),
    .testTarget(
      name: "CombineActionTests",
      dependencies: ["CombineAction"]
    )
  ]
)
