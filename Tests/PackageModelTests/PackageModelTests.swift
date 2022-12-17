//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift open source project
//
// Copyright (c) 2014-2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Basics
import TSCBasic
import TSCUtility
import XCTest

@testable import PackageModel

class PackageModelTests: XCTestCase {
  func testProductTypeCodable() throws {
    struct Foo: Codable, Equatable {
      var type: ProductType
    }

    func checkCodable(_ type: ProductType) {
      do {
        let foo = Foo(type: type)
        let data = try JSONEncoder.makeWithDefaults().encode(foo)
        let decodedFoo = try JSONDecoder.makeWithDefaults().decode(Foo.self, from: data)
        XCTAssertEqual(foo, decodedFoo)
      } catch {
        XCTFail("\(error)")
      }
    }

    checkCodable(.library(.automatic))
    checkCodable(.library(.static))
    checkCodable(.library(.dynamic))
    checkCodable(.executable)
    checkCodable(.test)
  }

  func testProductFilterCodable() throws {
    // Test ProductFilter.everything
    try {
      let data = try JSONEncoder().encode(ProductFilter.everything)
      let decoded = try JSONDecoder().decode(ProductFilter.self, from: data)
      XCTAssertEqual(decoded, ProductFilter.everything)
    }()
    // Test ProductFilter.specific(), including that the order is normalized
    try {
      let data = try JSONEncoder().encode(ProductFilter.specific(["Bar", "Foo"]))
      let decoded = try JSONDecoder().decode(ProductFilter.self, from: data)
      XCTAssertEqual(decoded, ProductFilter.specific(["Foo", "Bar"]))
    }()
  }

  func testAndroidCompilerFlags() throws {
    let triple = try Triple("x86_64-unknown-linux-android")
    let sdkDir = AbsolutePath(path: "/some/path/to/an/SDK.sdk")
    let toolchainPath = AbsolutePath(path: "/some/path/to/a/toolchain.xctoolchain")

    let destination = Destination(
      targetTriple: triple,
      sdkRootDir: sdkDir,
      toolchainBinDir: toolchainPath.appending(components: "usr", "bin")
    )

    XCTAssertEqual(
      try UserToolchain.deriveSwiftCFlags(
        triple: triple, destination: destination, environment: .process()),
      [
        // Needed when cross‐compiling for Android. 2020‐03‐01
        "-sdk", sdkDir.pathString,
      ])
  }

  func testWindowsLibrarianSelection() throws {
    // tiny PE binary from: https://archive.is/w01DO
    let contents: [UInt8] = [
      0x4d, 0x5a, 0x00, 0x00, 0x50, 0x45, 0x00, 0x00, 0x4c, 0x01, 0x01, 0x00,
      0x6a, 0x2a, 0x58, 0xc3, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
      0x04, 0x00, 0x03, 0x01, 0x0b, 0x01, 0x08, 0x00, 0x04, 0x00, 0x00, 0x00,
      0x00, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x0c, 0x00, 0x00, 0x00,
      0x04, 0x00, 0x00, 0x00, 0x0c, 0x00, 0x00, 0x00, 0x00, 0x00, 0x40, 0x00,
      0x04, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00,
      0x00, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
      0x68, 0x00, 0x00, 0x00, 0x64, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
      0x02,
    ]

    let triple = try Triple("x86_64-unknown-windows-msvc")
    let fs = TSCBasic.localFileSystem

    try withTemporaryFile { [contents] vfsPath in
      try withTemporaryDirectory(removeTreeOnDeinit: true) { [contents] tempDirPath in
        let binDir = tempDirPath.appending(component: "bin")

        let lld = binDir.appending(component: "lld-link.exe")
        try fs.writeFileContents(lld, bytes: ByteString(contents))

        let not = binDir.appending(component: "not-a-linker.exe")
        try fs.writeFileContents(not, bytes: ByteString(contents))

        #if !os(Windows)
          try fs.chmod(.executable, path: lld, options: [])
        #endif

        try XCTAssertEqual(
          UserToolchain.determineLibrarian(
            triple: triple, binDir: binDir, useXcrun: false, environment: [:], searchPaths: [],
            extraSwiftFlags: ["-Xswiftc", "-use-ld=lld"]),
          lld)

        try XCTAssertEqual(
          UserToolchain.determineLibrarian(
            triple: triple, binDir: binDir, useXcrun: false, environment: [:], searchPaths: [],
            extraSwiftFlags: ["-Xswiftc", "-use-ld=not-a-link.exe"]),
          not)

        try XCTAssertEqual(
          UserToolchain.determineLibrarian(
            triple: triple, binDir: binDir, useXcrun: false, environment: [:], searchPaths: [],
            extraSwiftFlags: ["-Xswiftc", "-use-ld=not-a-link.exe"]),
          AbsolutePath("link"))
      }
    }
  }
}
