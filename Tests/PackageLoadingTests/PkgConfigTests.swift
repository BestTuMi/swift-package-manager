/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest

import Basic
import PackageModel
import PackageLoading
import Utility
import TestSupport

extension CModule {
    convenience init(pkgConfig: String, providers: [SystemPackageProvider] = []) {
        self.init(
            name: "Foo",
            path: AbsolutePath("/fake"),
            pkgConfig: pkgConfig.isEmpty ? nil : pkgConfig,
            providers: providers.isEmpty ? nil : providers)
    }
}

class PkgConfigTests: XCTestCase {

    func testBasics() throws {
        // No pkgConfig name.
        do {
            let result = pkgConfigArgs(for: CModule(pkgConfig: ""))
            XCTAssertNil(result)
        }

        // No pc file.
        do {
            let module = CModule(
                pkgConfig: "Foo",
                providers: [
                    .brew(["libFoo"]),
                    .apt(["libFoo-dev"]),
                ]
            )
            let result = pkgConfigArgs(for: module)!
            XCTAssertEqual(result.pkgConfigName, "Foo")
            XCTAssertEqual(result.cFlags, [])
            XCTAssertEqual(result.libs, [])
            switch result.provider {
            case .brewItem(let names)?:
                XCTAssertEqual(names, ["libFoo"])
            case .aptItem(let names)?:
                XCTAssertEqual(names, ["libFoo-dev"])
            case nil:
                XCTFail("Expected a provider here")
            }
            XCTAssertTrue(result.couldNotFindConfigFile)
            switch result.error {
                case PkgConfigError.couldNotFindConfigFile?: break
                default: 
                XCTFail("Unexpected error \(String(describing: result.error))")
            }
        }

    let inputsDir = AbsolutePath(#file).parentDirectory.appending(components: "Inputs")
        // Pc file.
        try withCustomEnv(["PKG_CONFIG_PATH": inputsDir.asString]) {
            let result = pkgConfigArgs(for: CModule(pkgConfig: "Foo"))!
            XCTAssertEqual(result.pkgConfigName, "Foo")
            XCTAssertEqual(result.cFlags, ["-I/path/to/inc"])
            XCTAssertEqual(result.libs, ["-L/usr/da/lib", "-lSystemModule", "-lok"])
            XCTAssertNil(result.provider)
            XCTAssertNil(result.error)
            XCTAssertFalse(result.couldNotFindConfigFile)
        }

        // Pc file with non whitelisted flags.
        try withCustomEnv(["PKG_CONFIG_PATH": inputsDir.asString]) {
            let result = pkgConfigArgs(for: CModule(pkgConfig: "Bar"))!
            XCTAssertEqual(result.pkgConfigName, "Bar")
            XCTAssertEqual(result.cFlags, [])
            XCTAssertEqual(result.libs, [])
            XCTAssertNil(result.provider)
            XCTAssertFalse(result.couldNotFindConfigFile)
            switch result.error {
            case PkgConfigError.nonWhitelistedFlags(let desc)?:
                XCTAssertEqual(desc, "Non whitelisted flags found: [\"-DBlackListed\"] in pc file Bar")
            default:
                XCTFail("unexpected error \(result.error.debugDescription)")
            }
        }
    }

    static var allTests = [
        ("testBasics", testBasics),
    ]
}
