//===--- XPathTests.swift -------------------------------------------------===//
//
// This source file is part of the SwiftXML.org open source project
//
// Copyright (c) 2026 Stefan Springer (https://stefanspringer.com)
// and the SwiftXML project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
//===----------------------------------------------------------------------===//

import XCTest
import class Foundation.Bundle
@testable import SwiftXML

final class XPathTests: XCTestCase {
    
    func testXPath() throws {
        
        let source = """
            <a>
                <b id="b1"/>
                <b id="b2">
                    <c id="c1"/>
                    <d id="d1"/>
                    <c id="c2">This is an <i>italic</i> text.</c>
                    <d id="d2"/>
                </b>
                <b id="b3"/>
            </a>
            """
        
        let document = try readXML(fromText: source, registeringAttributeValuesFor: .selected(["id"]))
        
        // absolute path:
        let b2 = try document.goTo(xPath: "/a/b[2]")
        XCTAssertEqual(b2?.description, #"<b id="b2">"#)
        
        // if sevaral nodes are valid result, only the first is returned:
        XCTAssertEqual(try document.goTo(xPath: "/a/b")?.description, #"<b id="b1">"#)
        
        // relative path:
        XCTAssertEqual(try b2?.goTo(xPath: "c[2]")?.description, #"<c id="c2">"#)
        
        // simplest expressions:
        XCTAssertEqual(try document.goTo(xPath: "/")?.description, #"<a>"#)
        XCTAssertEqual(try b2?.goTo(xPath: "/")?.description, #"<a>"#)
        do {
            var errorText: String? = nil
            do {
                _ = try document.goTo(xPath: "")
            } catch {
                errorText = String(describing: error)
            }
            XCTAssertEqual(errorText, #"cannot execute XPath "": XPath expression is empty"#)
        }
        
        // using the dot `.`:
        XCTAssertEqual(try document.goTo(xPath: "/a/./b[2]/.")?.description, #"<b id="b2">"#)
        XCTAssertEqual(try document.goTo(xPath: "/.")?.description, #"<a>"#)
        
        // using the star `*`:
        XCTAssertEqual(try document.goTo(xPath: "/a/b[2]/*[2]")?.description, #"<d id="d1">"#)
        do {
            var errorText: String? = nil
            do {
                _ = try document.goTo(xPath: "/a/b[2]/*")
            } catch {
                errorText = String(describing: error)
            }
            XCTAssertEqual(errorText, #"cannot execute XPath "/a/b[2]/*": "*" without index or attribute condition is not suitable for determining a position within the document"#)
        }
        
        // text:
        XCTAssertEqual(try document.goTo(xPath: "/a/b[2]/c[2]/text()[2]")?.description, "\" text.\"")
        // ... but "text()" is not (!) supported:
        do {
            var errorText: String? = nil
            do {
                _ = try b2?.goTo(xPath: "/a/b[2]/c[2]/text()")
            } catch {
                errorText = String(describing: error)
            }
            XCTAssertEqual(errorText, #"cannot execute XPath "/a/b[2]/c[2]/text()": "text()" without an index is not suitable for determining a position within the document"#)
        }
        
        // attribute condition:
        XCTAssertEqual(try document.goTo(xPath: "/a/b[2]/*[@id='d2']")?.description, #"<d id="d2">"#)
        XCTAssertEqual(try document.goTo(xPath: "/a/b[2]/c[@id='d2']")?.description, nil)
        XCTAssertEqual(try document.goTo(xPath: "/a/b[2]/d[@id='d2']")?.description, #"<d id="d2">"#)
        
        // search for an element with a certain attribute value in the whole document first:
        XCTAssertEqual(try document.goTo(xPath: "//*[@id='b2']")?.description, #"<b id="b2">"#)
        XCTAssertEqual(try document.goTo(xPath: "//*[@id='b2']/d[1]")?.description, #"<d id="d1">"#)
    }
    
}
