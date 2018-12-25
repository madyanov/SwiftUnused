//
//  SwiftUnused.swift
//  SwiftUnusedFramework
//
//  Created by Roman Madyanov on 22/12/2018.
//

import Foundation
import SourceKittenFramework

public struct SwiftUnused {
    public var declarationsAndUsages: (declarations: Set<Declaration>, usages: Set<Usage>) {
        var declarations = Set<Declaration>()
        var usages = Set<Usage>()

        for token in syntaxMap.tokens {
            guard let cursorInfo = try? Request.cursorInfo(
                file: path,
                offset: Int64(token.offset),
                arguments: arguments
            ).send() else {
                continue
            }

            guard
                let kind = cursorInfo.kind,
                let name = cursorInfo.name,
                let usr = cursorInfo.usr?.split(separator: "_").first,
                let typeUSR = cursorInfo.typeUSR?.split(separator: "_").first,
                let (line, column) = (file.contents as NSString).lineAndCharacter(forByteOffset: token.offset)
            else {
                continue
            }

            if SwiftDeclarationKind(rawValue: kind) != nil {
                guard isDeclarationProcessable(cursorInfo) else {
                    continue
                }

                declarations.insert(Declaration(
                    usr: String(usr),
                    typeUSR: String(typeUSR),
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
    private let file: File
    private let syntaxMap: SyntaxMap

    public init?(path: String, arguments: [String]) {
        guard let file = File(path: path), let syntaxMap = try? SyntaxMap(file: file) else {
            return nil
        }

        self.path = path
        self.arguments = arguments
        self.file = file
        self.syntaxMap = syntaxMap
    }

    private func isDeclarationProcessable(_ cursorInfo: [String: SourceKitRepresentable]) -> Bool {
        // skip outlets, actions, overrides & public declarations
        if let fullyAnnotatedDeclaration = cursorInfo.fullyAnnotatedDeclaration,
            [
                "<syntaxtype.attribute.name>@IBOutlet</syntaxtype.attribute.name>",
                "<syntaxtype.attribute.name>@IBAction</syntaxtype.attribute.name>",
                "<syntaxtype.keyword>override</syntaxtype.keyword>",
                "<syntaxtype.keyword>public</syntaxtype.keyword>",
            ].contains(where: fullyAnnotatedDeclaration.contains)
        {
            return false
        }

        return true
    }
}

public struct Declaration: Hashable {
    public let usr: String
    public let typeUSR: String
    public let name: String
    public let file: String
    public let line: Int
    public let column: Int

    public func hash(into hasher: inout Hasher) {
        hasher.combine(usr)
        hasher.combine(typeUSR)
    }
}

public struct Usage: Hashable {
    public let usr: String
    public let typeUSR: String
}

private extension Dictionary where Key == String, Value == SourceKitRepresentable {
    private enum CursorInfoKey: String {
        case kind = "key.kind"
        case name = "key.name"
        case usr = "key.usr"
        case typeUSR = "key.typeusr"
        case fullyAnnotatedDeclaration = "key.fully_annotated_decl"
    }

    var kind: String? {
        return self[CursorInfoKey.kind.rawValue] as? String
    }

    var name: String? {
        return self[CursorInfoKey.name.rawValue] as? String
    }

    var usr: String? {
        return self[CursorInfoKey.usr.rawValue] as? String
    }

    var typeUSR: String? {
        return self[CursorInfoKey.typeUSR.rawValue] as? String
    }

    var fullyAnnotatedDeclaration: String? {
        return self[CursorInfoKey.fullyAnnotatedDeclaration.rawValue] as? String
    }
}
