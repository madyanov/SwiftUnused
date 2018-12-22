//
//  SwiftUnused.swift
//  SwiftUnusedFramework
//
//  Created by Roman Madyanov on 22/12/2018.
//

import Foundation
import SourceKittenFramework

public struct SwiftUnused {
    public var declarations: Set<USR> {
        return usrs(index, declarations: true)
    }

    public var usages: Set<USR> {
        return usrs(index, declarations: false)
    }

    private let path: String
    private let index: [String: SourceKitRepresentable]

    public init?(path: String, arguments: [String]? = nil) {
        let arguments = arguments ?? [
            "-target", "arm64-apple-ios12.1",
            "-sdk", "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS12.1.sdk",
            "-j4", path
        ]

        guard let index = try? Request.index(file: path, arguments: arguments).send() else {
            return nil
        }

        self.path = path
        self.index = index
    }

    private func usrs(_ index: [String: SourceKitRepresentable], declarations: Bool) -> Set<USR> {
        var result = Set<USR>()

        if let entities = index[IndexRequestKey.entities.rawValue] as? [[String: SourceKitRepresentable]] {
            result = entities.reduce(Set<USR>()) { result, index in
                return result.union(usrs(index, declarations: declarations))
            }
        }

        guard
            let kind = index[IndexRequestKey.kind.rawValue] as? String,
            (SwiftDeclarationKind(rawValue: kind) != nil) == declarations
        else {
            return result
        }

        guard !declarations || SwiftDeclarationKind(rawValue: kind) != .enumelement else {
            return result
        }

        guard
            let usr = index[IndexRequestKey.usr.rawValue] as? String,
            let name = index[IndexRequestKey.name.rawValue] as? String,
            let line = index[IndexRequestKey.line.rawValue] as? Int64,
            let column = index[IndexRequestKey.column.rawValue] as? Int64
        else {
            return result
        }

        result.insert(USR(usr: usr, name: name, file: path, line: line, column: column))
        return result
    }
}

public struct USR: Hashable {
    public let usr: String
    public let name: String
    public let file: String
    public let line: Int64
    public let column: Int64

    public var hashValue: Int {
        return usr.hashValue
    }

    public static func == (left: USR, right: USR) -> Bool {
        return left.usr == right.usr
    }
}

private enum IndexRequestKey: String {
    case kind = "key.kind"
    case usr = "key.usr"
    case name = "key.name"
    case line = "key.line"
    case column = "key.column"
    case entities = "key.entities"
}
