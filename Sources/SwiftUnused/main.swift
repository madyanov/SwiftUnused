//
//  main.swift
//  SwiftUnused
//
//  Created by Roman Madyanov on 22/12/2018.
//

#if os(Linux)
    import Glibc
#else
    import Darwin.C
#endif

import Foundation
import SwiftUnusedFramework

let arguments = [
    "-target", "arm64-apple-ios12.1",
    "-sdk", "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS12.1.sdk",
    "-j4",
    // paths
]

let fileManager = FileManager.default

guard let baseURL = URL(string: fileManager.currentDirectoryPath)?
    .appendingPathComponent(CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
else {
    exit(1)
}

var paths = [String]()
let enumerator = fileManager.enumerator(atPath: baseURL.absoluteString)

while let path = enumerator?.nextObject() as? String {
    let url = baseURL.appendingPathComponent(path)

    guard path.hasSuffix(".swift") else {
        continue
    }

    paths.append(url.absoluteString)
}

var allDeclarations = Set<Declaration>()
var allUsages = Set<Usage>()

for path in paths {
    print("Processing file \(path)... ", terminator: "")
    fflush(stdout)

    guard let file = File(path: path, arguments: arguments + paths) else {
        print("error")
        continue
    }

    print("done")

    let (declarations, usages) = file.declarationsAndUsages
    allDeclarations = allDeclarations.union(declarations)
    allUsages = allUsages.union(usages)
}

print()

outerLoop: for declaration in allDeclarations {
    for usage in allUsages where declaration.usr == usage.usr || declaration.typeUSR == usage.typeUSR {
        continue outerLoop
    }

    print("Unused declaration \"\(declaration.name)\" in \(declaration.file):\(declaration.line)")
}

// test

let x = "123"

class A {
    func a() { }
}

class B: A {
    override func a() { }
}
