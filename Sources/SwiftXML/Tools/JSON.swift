//===--- JSONToXMLToJSON.swift ---------------------------------------------===//
//
// This source file is part of the SwiftXML.org open source project
//
// Copyright (c) 2021-2023 Stefan Springer (https://stefanspringer.com)
// and the SwiftXML project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
//===----------------------------------------------------------------------===//

import Foundation

public struct JSONError: LocalizedError, CustomStringConvertible {

    private let message: String

    public init(_ message: String) {
        self.message = message
    }
    
    public var description: String { message }
    
    public var errorDescription: String? { message }
}

fileprivate extension String {
    
    var escapedForJSON: String {
        self.replacing(#"\"#, with: #"\\"#).replacing(#"""#, with: #"\""#)
    }
    
}

public func readJSONAsXML(fromData data: Data, usingJSONKeyOrder jsonKeyOrder: [String]? = nil) throws -> XDocument {
    let json = try JSONSerialization.jsonObject(with: data, options: .mutableLeaves)
    let xmlContent = try toXML(json: json, usingJSONKeyOrder: jsonKeyOrder)
    return XDocument(registeringValuesForAttributes: .selected(["key"])) { xmlContent }
}

public func readJSONAsXML(fromURL url: URL, usingJSONKeyOrder jsonKeyOrder: [String]? = nil) throws -> XDocument {
    try readJSONAsXML(fromData: try Data(contentsOf: url), usingJSONKeyOrder: jsonKeyOrder)
}

public func readJSONAsXML(fromText text: String, usingJSONKeyOrder jsonKeyOrder: [String]? = nil) throws -> XDocument {
    guard let data = text.data(using: .utf8) else {
        throw JSONError("could not get UTF8 data from text")
    }
    return try readJSONAsXML(fromData: data, usingJSONKeyOrder: jsonKeyOrder)
}

public func toXML(json: Any, usingJSONKeyOrder jsonKeyOrder: [String]? = nil) throws -> XContent? {
    switch json {
    case let boolean as Bool:
        return XElement("boolean") { XText(boolean.description) }
    case let text as String:
        return XElement("text") { XText(text) }
    case let number as Int:
        return XElement("number") { String(number) }
    case let number as Double:
        return XElement("number") { String(number) }
    case let object as [String : Any]:
        let element = XElement("object")
        for (key, value) in object.sorted(by: jsonKeyOrder != nil ? {
            if let index0 = jsonKeyOrder!.firstIndex(of: $0.key), let index1 = jsonKeyOrder!.firstIndex(of: $1.key) {
                index0 < index1
            } else {
                $0.key < $1.key
            }
        } : { $0.key < $1.key }) {
            let content = try toXML(json: value, usingJSONKeyOrder: jsonKeyOrder)
            element.add { XElement("property", ["key": key]) { content } }
        }
        return element
    case let array as [Any]:
        let element = XElement("array")
        for item in array {
            let content = try toXML(json: item, usingJSONKeyOrder: jsonKeyOrder)
            element.add { content }
        }
        return element
    default:
        if String(describing: json).contains("null") {
            return XElement("null")
        } else {
            throw JSONError("JSON: Unknown type \(type(of: json)): \(json).")
        }
    }
}

fileprivate let _indendationStep = "  "

public extension XContent {
    
    /// `indendationStep` is the text used for each level of indentation.
    func writeAsJSON(to writer: Writer, indentationLevel: Int = 0, indendationStep: String? = nil, lineEnding: String = "\n") throws {
        let indendationStep = indendationStep ?? _indendationStep
        switch self {
        case let element as XElement:
            switch element.name {
            case "array":
                let repeatedIndentation = String(repeating: indendationStep, count: indentationLevel + 1)
                try writer.write("[\(lineEnding)\(repeatedIndentation)")
                var delim = false
                for content in self.content {
                    if delim { try writer.write(",\(lineEnding)\(repeatedIndentation)") } else { delim = true }
                    try content.writeAsJSON(to: writer, indentationLevel: indentationLevel + 1, lineEnding: lineEnding)
                }
                try writer.write("\(lineEnding)\(String(repeating: indendationStep, count: indentationLevel))]")
            case "object":
                let repeatedIndentation = String(repeating: indendationStep, count: indentationLevel + 1)
                try writer.write("{\(lineEnding)\(repeatedIndentation)")
                var delim = false
                for content in self.content {
                    if delim { try writer.write(",\(lineEnding)\(repeatedIndentation)") } else { delim = true }
                    try content.writeAsJSON(to: writer, indentationLevel: indentationLevel, lineEnding: lineEnding)
                }
                try writer.write("\(lineEnding)\(String(repeating: indendationStep, count: indentationLevel))}")
            case "property":
                guard let key = element["key"] else { throw JSONError("property without key: \(element)") }
                try writer.write("\"\(key.escapedForJSON)\": ")
                if let content = element.firstContent {
                    guard content.nextTouching == nil else { throw JSONError("too much content in property \(element)") }
                    try content.writeAsJSON(to: writer, indentationLevel: indentationLevel + 1, lineEnding: lineEnding)
                } else {
                    try writer.write("\"\"")
                }
            case "text":
                try writer.write("\"\(element.allTextsCombined.escapedForJSON)\"")
            case "number", "boolean":
                try writer.write(element.allTextsCombined)
            case "null":
                try writer.write("null")
            default:
                throw JSONError("cannot convert \(self) to JSON")
            }
        default: throw JSONError("cannot convert \(self) to JSON")
        }
    }
    
    /// `indendationStep` is the text used for each level of indentation.
    func writeAsJSON(toURL url: URL, indendationStep: String? = nil, lineEnding: String = "\n") throws {
        let path = url.path()
        _ = FileManager.default.createFile(atPath: path,  contents:Data("".utf8), attributes: nil)
        if let fileHandle = FileHandle(forWritingAtPath: path) {
            try BufferedFileWriter.using(fileHandle) { writer in
                try writeAsJSON(to: writer, indendationStep: indendationStep, lineEnding: lineEnding)
            }
            fileHandle.closeFile()
        } else {
            throw SwiftXMLError("cannot write to [\(path)]");
        }
    }
    
}

public extension XDocument {
    
    /// `indendationStep` is the text used for each level of indentation.
    func writeAsJSON(to writer: Writer, indendationStep: String? = nil, lineEnding: String = "\n") throws {
        for content in self.content {
            try content.writeAsJSON(to: writer, indendationStep: indendationStep, lineEnding: lineEnding)
        }
    }
    
    /// `indendationStep` is the text used for each level of indentation.
    func writeAsJSON(toURL url: URL, indendationStep: String? = nil, lineEnding: String = "\n") throws {
        let path = url.path()
        _ = FileManager.default.createFile(atPath: path,  contents:Data("".utf8), attributes: nil)
        if let fileHandle = FileHandle(forWritingAtPath: path) {
            try BufferedFileWriter.using(fileHandle) { writer in
                try writeAsJSON(to: writer, indendationStep: indendationStep, lineEnding: lineEnding)
            }
            fileHandle.closeFile()
        } else {
            throw SwiftXMLError("cannot write to [\(path)]");
        }
    }
    
}
