// swift-tools-version: 5.10
import PackageDescription

let package = Package(
  name: "ExerciseCore",
  platforms: [.iOS(.v17), .macOS(.v13), .watchOS(.v10)],
  products: [
    .library(name: "ExerciseCore", targets: ["ExerciseCore"]),
    .executable(name: "posetrack", targets: ["posetrack"]),
  ],
  dependencies: [
    // The Mac tool's flags only; the library and the app's targets stay dependency-free.
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.8.2"),
  ],
  targets: [
    // Mac-only tool: runs the pose model on a clip and analyzes it like the phone (see docs/TESTING.md).
    .executableTarget(
      name: "posetrack",
      dependencies: ["ExerciseCore", .product(name: "ArgumentParser", package: "swift-argument-parser")]),
    .target(name: "ExerciseCore"),
    .testTarget(
      name: "ExerciseCoreTests", dependencies: ["ExerciseCore"],
      resources: [.copy("Fixtures")]),
  ]
)
