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
        return Set(syntaxMap.tokens.compactMap { usrForTokenAt($0.offset, declaration: true) })
    }

    public var usages: Set<USR> {
        return Set(syntaxMap.tokens
            .filter {
                $0.type == SyntaxKind.identifier.rawValue ||
                $0.type == SyntaxKind.typeidentifier.rawValue
            }
            .compactMap {
                usrForTokenAt($0.offset, declaration: false)
            })
    }

    private let file: File
    private let path: String
    private let arguments: [String]
    private let syntaxMap: SyntaxMap

    public init?(path: String, arguments: [String]? = nil) {
        guard let file = File(path: path) else {
            return nil
        }

        do {
            syntaxMap = try SyntaxMap(file: file)
        } catch {
            return nil
        }

        self.file = file
        self.path = path
        self.arguments = arguments ?? ["-sdk", sdkPath(), "-j4", path]
    }

    private func usrForTokenAt(_ offset: Int, declaration: Bool) -> USR? {
        do {
            let cursorInfo = try Request.cursorInfo(file: path, offset: Int64(offset), arguments: arguments).send()

            guard
                let kind = cursorInfo[CursorInfoKey.kind.rawValue] as? String,
                (SwiftDeclarationKind(rawValue: kind) != nil) == declaration,
                !declaration || isDeclarationProcessable(cursorInfo)
            else {
                return nil
            }

            guard
                let usr = cursorInfo[CursorInfoKey.usr.rawValue] as? String,
                let name = cursorInfo[CursorInfoKey.name.rawValue] as? String,
                let (line, column) = (file.contents as NSString).lineAndCharacter(forByteOffset: offset)
            else {
                return nil
            }

            return USR(usr: usr, name: name, file: path, line: line, column: column)
        } catch {
            return nil
        }
    }

    private func isDeclarationProcessable(_ cursorInfo: [String: SourceKitRepresentable]) -> Bool {
        guard
            let kind = cursorInfo[CursorInfoKey.kind.rawValue] as? String,
            let declarationKind = SwiftDeclarationKind(rawValue: kind),
            declarationKind != .enumelement
        else {
            return false
        }

        if let fullyAnnotatedDeclaration = cursorInfo[CursorInfoKey.fullyAnnotatedDeclaration.rawValue] as? String,
            [
                "<syntaxtype.attribute.name>@IBOutlet</syntaxtype.attribute.name>",
                "<syntaxtype.attribute.name>@IBAction</syntaxtype.attribute.name>",
                "<syntaxtype.attribute.name>@objc</syntaxtype.attribute.name>",
                "<syntaxtype.keyword>override</syntaxtype.keyword>",
                "<syntaxtype.keyword>public</syntaxtype.keyword>",
            ].contains(where: fullyAnnotatedDeclaration.contains)
        {
            return false
        }

        return true
    }
}

public struct USR: Hashable {
    public let usr: String
    public let name: String
    public let file: String
    public let line: Int
    public let column: Int

    public var hashValue: Int {
        return usr.hashValue
    }

    public static func == (left: USR, right: USR) -> Bool {
        return left.usr == right.usr
    }
}

private enum CursorInfoKey: String {
    case name = "key.name"
    case kind = "key.kind"
    case usr = "key.usr"
    case overrides = "key.overrides"
    case fullyAnnotatedDeclaration = "key.fully_annotated_decl"
}
