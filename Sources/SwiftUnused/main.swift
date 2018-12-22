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

let fileManager = FileManager.default

guard let baseURL = URL(string: fileManager.currentDirectoryPath)?
    .appendingPathComponent(CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
else {
    exit(1)
}

let enumerator = fileManager.enumerator(atPath: baseURL.absoluteString)

var declarations = Set<USR>()
var usages = Set<USR>()

while let path = enumerator?.nextObject() as? String {
    let url = baseURL.appendingPathComponent(path)

    guard path.hasSuffix(".swift") else {
        continue
    }

    print("Processing file \(path)... ", terminator: "")
    fflush(stdout)

    guard let swiftUnused = SwiftUnused(path: url.absoluteString) else {
        print("error")
        continue
    }

    declarations = declarations.union(swiftUnused.declarations)
    usages = usages.union(swiftUnused.usages)

    print("done")
}

print()

for declaration in declarations where !usages.contains(declaration) {
    print("Unused declaration \"\(declaration.name)\" \"\(declaration.usr)\" in \(declaration.file):\(declaration.line)")
}

// test

let x = "123"

class A {
    func a() { }
}

class B: A {
    override func a() { }
}
