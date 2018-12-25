//
//  SwiftUnused.swift
//  SwiftUnusedFramework
//
//  Created by Roman Madyanov on 22/12/2018.
//

import Foundation
import SourceKittenFramework

private typealias SourceKittenFile = SourceKittenFramework.File

public struct File {
    public var declarationsAndUsages: (declarations: Set<Declaration>, usages: Set<Usage>) {
        var declarations = Set<Declaration>()
        var usages = Set<Usage>()
        var protocols = Set<String>()

        for token in syntaxMap.tokens {
            guard let cursorInfo = try? Request.cursorInfo(
                file: path,
                offset: Int64(token.offset),
                arguments: arguments
            ).send() else {
                continue
            }

            guard
                let kind: String = cursorInfo[.kind],
                let name: String = cursorInfo[.name],
                let usr = trimUSR(cursorInfo[.usr]),
                let typeUSR = trimUSR(cursorInfo[.typeUSR]),
                let (line, column) = (file.contents as NSString).lineAndCharacter(forByteOffset: token.offset)
            else {
                continue
            }

            if let declarationKind = SwiftDeclarationKind(rawValue: kind) {
                if declarationKind == .protocol {
                    protocols.insert(name)
                }

                guard isDeclarationProcessable(cursorInfo, protocols: protocols) else {
                    continue
                }

                declarations.insert(Declaration(
                    usr: String(usr),
                    typeUSR: String(typeUSR),
                    isType: token.type == SyntaxKind.typeidentifier.rawValue,
                    name: name,
                    file: path,
                    line: line,
                    column: column
                ))
            } else {
                usages.insert(Usage(usr: String(usr), typeUSR: String(typeUSR)))
            }
        }

        return (declarations, usages)
    }

    private let path: String
    private let arguments: [String]
    private let file: SourceKittenFile
    private let syntaxMap: SyntaxMap

    public init?(path: String, arguments: [String]) {
        guard let file = SourceKittenFile(path: path), let syntaxMap = try? SyntaxMap(file: file) else {
            return nil
        }

        self.path = path
        self.arguments = arguments
        self.file = file
        self.syntaxMap = syntaxMap
    }

    private func isDeclarationProcessable(_ cursorInfo: [String: SourceKitRepresentable], protocols: Set<String>) -> Bool {
        // skip outlets, actions, overrides, public & open declarations
        if let fullyAnnotatedDeclaration: String = cursorInfo[.fullyAnnotatedDeclaration],
            [
                "<syntaxtype.attribute.name>@IBOutlet</syntaxtype.attribute.name>",
                "<syntaxtype.attribute.name>@IBAction</syntaxtype.attribute.name>",
                "<syntaxtype.keyword>override</syntaxtype.keyword>",
                "<syntaxtype.keyword>public</syntaxtype.keyword>",
                "<syntaxtype.keyword>open</syntaxtype.keyword>",
            ].contains(where: fullyAnnotatedDeclaration.contains)
        {
            return false
        }

        // skip protocol members
        if let name: String = cursorInfo[.name], !protocols.contains(name) {
            for `protocol` in protocols where isProtocolMemberUSR(cursorInfo[.usr], protocol: `protocol`) {
                return false
            }
        }

        // TODO: skip members inside public extensions

        return true
    }

    private func isProtocolMemberUSR(_ usr: String?, protocol: String) -> Bool {
        let length = `protocol`.count
        return usr?.range(of: "\\D\(length)\(`protocol`)P", options: .regularExpression) != nil
    }

    private func trimUSR(_ usr: String?) -> String? {
        guard let splitUSR = usr?.split(separator: "_").first else {
            return usr
        }

        return splitUSR.replacingOccurrences(of: "\\d+$", with: "", options: .regularExpression)
    }
}

public struct Declaration: Hashable {
    public let usr: String
    public let typeUSR: String
    public let isType: Bool
    public let name: String
    public let file: String
    public let line: Int
    public let column: Int

    public func hash(into hasher: inout Hasher) {
        hasher.combine(usr)
        hasher.combine(typeUSR)
    }

    public static func == (left: Declaration, right: Declaration) -> Bool {
        return left.usr == right.usr && left.typeUSR == right.typeUSR
    }
}

public struct Usage: Hashable {
    public let usr: String
    public let typeUSR: String
}

private extension Dictionary where Key == String, Value == SourceKitRepresentable {
    enum CursorInfoKey: String {
        case kind = "key.kind"
        case name = "key.name"
        case usr = "key.usr"
        case typeUSR = "key.typeusr"
        case fullyAnnotatedDeclaration = "key.fully_annotated_decl"
    }

    subscript<T>(key: CursorInfoKey) -> T? {
        return self[key.rawValue] as? T
    }
}
