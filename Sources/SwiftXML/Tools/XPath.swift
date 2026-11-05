//===--- XPath.swift ------------------------------------------------------===//
//
// This source file is part of the SwiftXML.org open source project
//
// Copyright (c) 2026 Stefan Springer (https://stefanspringer.com)
// and the SwiftXML project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
//===----------------------------------------------------------------------===//

import Foundation

public struct XPathError: LocalizedError, CustomStringConvertible {

    private let message: String

    public init(_ message: String) {
        self.message = message
    }
    
    public var description: String { message }
    
    public var errorDescription: String? { message }
}

public extension XNode {
    
    /// Go to the XPath `xPath` starting with the current node.
    /// Note that the full XPath syntax is not supported yet.
    func goTo(xPath originalXPath: String) throws -> XContent? {
        let generalErrorMessage = "cannot execute XPath"
        var xPath = Substring(originalXPath)
        var currentNode: XNode
        if xPath.isEmpty {
            throw XPathError("\(generalErrorMessage) \"\(originalXPath)\": XPath expression is empty")
        } else if let attributeValueInDocumentMatch = xPath.firstMatch(of: #/^\/\/\*\[@([^=]+)='([^']+)'\]/#) {
            let attributeName = String(attributeValueInDocumentMatch.output.1)
            if document?.areAttributeValuesRegistered(forName: attributeName) != true {
                throw XPathError("\(generalErrorMessage) \"\(originalXPath)\": values for attribute \"\(attributeName)\" are not registered")
            }
            let attributeValue = String(attributeValueInDocumentMatch.output.2)
            if let element = document?.registeredValues(attributeValue, forAttribute: attributeName).first?.element {
                currentNode = element
                xPath = xPath[attributeValueInDocumentMatch.range.upperBound...]
                if xPath.hasPrefix("/") {
                    xPath = xPath.dropFirst()
                }
            } else {
                return nil
            }
        } else if xPath.hasPrefix("/") {
            guard let document = self.document else {
                throw XPathError("\(generalErrorMessage) \"\(originalXPath)\": node \(self) not in any document")
            }
            currentNode = document
            xPath = xPath.dropFirst(1)
        } else {
            currentNode = self
        }
        
        if xPath.isEmpty {
            if currentNode === document {
                return document?.firstChild
            } else {
                guard let content = currentNode as? XContent else {
                    throw XPathError("\(generalErrorMessage) \"\(originalXPath)\": found non-document node that is not a content node") // should not happen
                }
                return content
            }
        }
        
        /// `designation` with value `nil`means "any child element".
        func decompose(stepExpression: Substring) throws -> (designation: Substring?, number: Int?, attributeCondition: (attributeName: String, attributeValue: String)?) {
            let designation: Substring
            var number: Int? = nil
            var attributeCondition: (attributeName: String, attributeValue: String)? = nil
            if let conditionMatch = stepExpression.firstMatch(of: /\[([^\]]+)\]$/) {
                designation = stepExpression[..<conditionMatch.range.lowerBound]
                let condition = conditionMatch.output.1
                if condition.contains(/^\d+$/) {
                    number = Int(condition)
                    if let number {
                        if number < 1 {
                            throw XPathError("\(generalErrorMessage) \"\(originalXPath)\": number \"\(number)\" has incorrect value")
                        }
                    } else { // should not happen
                        throw XPathError("\(generalErrorMessage) \"\(originalXPath)\": could not convert \"\(condition)\" to number")
                    }
                } else if let attributeConditionMatch = condition.firstMatch(of: /^@([^=]+)='([^']+)'$/) {
                    attributeCondition = (attributeName: String(attributeConditionMatch.output.1), attributeValue: String(attributeConditionMatch.output.2))
                } else {
                    throw XPathError("\(generalErrorMessage) \"\(originalXPath)\": cannot interpret condition \"\(condition)\"")
                }
            } else {
                designation = stepExpression
            }
            
            if designation == "*" {
                return (designation: nil, number: number, attributeCondition: attributeCondition)
            }
            
            if designation == "." || designation == "text()" || designation == "node()" {
                return (designation: designation, number: number, attributeCondition: attributeCondition)
            }
            
            guard designation.contains(/^(?!xml)[a-zA-Z_][a-zA-Z0-9._-]*$/) else {
                throw XPathError("\(generalErrorMessage) \"\(originalXPath)\": cannot interpret \"\(designation)\"")
            }
            
            return (designation: designation, number: number, attributeCondition: attributeCondition)
        }
        
        let enumeratedParts = Array(xPath.split(separator: "/", omittingEmptySubsequences: false).enumerated())
        var lastDesignation: Substring? = nil
        for enumeratedPart in enumeratedParts {
            if lastDesignation == "text()" {
                throw XPathError("\(generalErrorMessage) \"\(originalXPath)\": expression after \"text()[...]\"")
            }
            let (designation: designation, number: number, attributeCondition: attributeCondition) = try decompose(stepExpression: enumeratedPart.element)
            if let designation, designation == "text()" {
                if attributeCondition != nil {
                    throw XPathError("\(generalErrorMessage) \"\(originalXPath)\": \"\(designation)\" should not have an attribute condition")
                }
                guard let number else {
                    throw XPathError("\(generalErrorMessage) \"\(originalXPath)\": \"\(designation)\" without an index is not suitable for determining a position within the document")
                }
                if enumeratedPart.offset >= enumeratedParts.count {
                    throw XPathError("\(generalErrorMessage) \"\(originalXPath)\": \"\(designation)[...]\" should be the last part expression")
                }
                if let node = currentNode.immediateTexts.dropFirst(number-1).first {
                    currentNode = node
                } else {
                    return nil
                }
            } else {
                if designation == "." {
                    if let document = currentNode as? XDocument {
                        if let child = document.firstChild {
                            currentNode = child
                        } else {
                            return nil
                        }
                    } else if let number {
                        throw XPathError("\(generalErrorMessage) \"\(originalXPath)\": cannot apply number \"\(number)\" to \".\"")
                    } else if let attributeCondition {
                        if let currentElement = currentNode as? XElement, currentElement[attributeCondition.attributeName] != attributeCondition.attributeValue {
                            return nil
                        }
                    }
                } else {
                    let nextNode: XNode?
                    let sequence = if let designation {
                        if designation == "node()" {
                            currentNode.content
                        } else {
                            currentNode.content({ ($0 as? XElement)?.name == String(designation) })
                        }
                    } else {
                        currentNode.content({ $0 is XElement })
                    }
                    if let attributeCondition {
                        let _seq = sequence.filter{ ($0 as? XElement)?[attributeCondition.attributeName] == attributeCondition.attributeValue }
                        if let number {
                            nextNode = _seq.dropFirst(number-1).first
                        } else {
                            nextNode = _seq.first
                        }
                    } else {
                        if let number {
                            nextNode = sequence.dropFirst(number-1).first
                        } else {
                            let iterator = sequence.makeIterator()
                            nextNode = iterator.next()
                            if iterator.next() != nil {
                                throw XPathError("\(generalErrorMessage) \"\(originalXPath)\": number is missing because multiple nodes meet the condition")
                            }
                        }
                    }
                    if let nextNode {
                        currentNode = nextNode
                    } else {
                        return nil
                    }
                }
            }
            lastDesignation = designation
        }
        
        guard let content = currentNode as? XContent else {
            throw XPathError("\(generalErrorMessage) \"\(originalXPath)\": target is not a document content") // should not happen
        }
        return content
    }
    
}
