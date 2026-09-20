//===--- JSONTests.swift --------------------------------------------------===//
//
// This source file is part of the SwiftXML.org open source project
//
// Copyright (c) 2021-2023 Stefan Springer (https://stefanspringer.com)
// and the SwiftXML project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
//===----------------------------------------------------------------------===//

import XCTest
import class Foundation.Bundle
@testable import SwiftXML

final class JSONTests: XCTestCase {
    
    func testJSON() throws {
        
        let jsonSource = """
            {
              "id": "emp-98765",
              "isActive": true,
              "personalInfo": {
                "firstName": "Maximilian",
                "lastName": "Mustermann",
                "age": 34,
                "contact": {
                  "email": "m.mustermann@techcorp.de",
                  "phone": "+49 170 1234567"
                }
              },
              "roles": [
                "Senior Developer",
                "Tech Lead",
                "Scrum Master"
              ],
              "skills": [
                {
                  "name": "JavaScript",
                  "level": "Expert",
                  "yearsOfExperience": 8
                },
                {
                  "name": "Python",
                  "level": "Advanced",
                  "yearsOfExperience": 4
                },
                {
                  "name": "Docker",
                  "level": "Intermediate",
                  "yearsOfExperience": 2
                }
              ],
              "currentProject": {
                "projectId": "proj-abc-2026",
                "name": "Cloud Migration",
                "budget": 250000.5,
                "deadline": "2026-12-31",
                "teamMembers": [
                  "Alice",
                  "Bob",
                  "Charlie"
                ]
              },
              "terminationDate": null
            }
            """
        
        let xmlDocument = try readJSONAsXML(fromText: jsonSource, usingJSONKeyOrder: [
            "id",
            "isActive",
            "personalInfo",
            "firstName",
            "lastName",
            "age",
            "contact",
            "email",
            "phone",
            "roles",
            "skills",
            "projectId",
            "name",
            "level",
            "yearsOfExperience",
            "currentProject",
            "budget",
            "deadline",
            "teamMembers",
            "terminationDate",
        ])
        
        XCTAssertEqual(xmlDocument.serialized(pretty: true), """
            <object>
                <property key="id">
                    <text>emp-98765</text>
                </property>
                <property key="isActive">
                    <boolean>true</boolean>
                </property>
                <property key="personalInfo">
                    <object>
                        <property key="firstName">
                            <text>Maximilian</text>
                        </property>
                        <property key="lastName">
                            <text>Mustermann</text>
                        </property>
                        <property key="age">
                            <number>34</number>
                        </property>
                        <property key="contact">
                            <object>
                                <property key="email">
                                    <text>m.mustermann@techcorp.de</text>
                                </property>
                                <property key="phone">
                                    <text>+49 170 1234567</text>
                                </property>
                            </object>
                        </property>
                    </object>
                </property>
                <property key="roles">
                    <array>
                        <text>Senior Developer</text>
                        <text>Tech Lead</text>
                        <text>Scrum Master</text>
                    </array>
                </property>
                <property key="skills">
                    <array>
                        <object>
                            <property key="name">
                                <text>JavaScript</text>
                            </property>
                            <property key="level">
                                <text>Expert</text>
                            </property>
                            <property key="yearsOfExperience">
                                <number>8</number>
                            </property>
                        </object>
                        <object>
                            <property key="name">
                                <text>Python</text>
                            </property>
                            <property key="level">
                                <text>Advanced</text>
                            </property>
                            <property key="yearsOfExperience">
                                <number>4</number>
                            </property>
                        </object>
                        <object>
                            <property key="name">
                                <text>Docker</text>
                            </property>
                            <property key="level">
                                <text>Intermediate</text>
                            </property>
                            <property key="yearsOfExperience">
                                <number>2</number>
                            </property>
                        </object>
                    </array>
                </property>
                <property key="currentProject">
                    <object>
                        <property key="projectId">
                            <text>proj-abc-2026</text>
                        </property>
                        <property key="name">
                            <text>Cloud Migration</text>
                        </property>
                        <property key="budget">
                            <number>250000.5</number>
                        </property>
                        <property key="deadline">
                            <text>2026-12-31</text>
                        </property>
                        <property key="teamMembers">
                            <array>
                                <text>Alice</text>
                                <text>Bob</text>
                                <text>Charlie</text>
                            </array>
                        </property>
                    </object>
                </property>
                <property key="terminationDate">
                    <null/>
                </property>
            </object>
            """)
        
        let writer = CollectingWriter()
        try xmlDocument.writeAsJSON(to: writer)
        XCTAssertEqual(writer.description, jsonSource)
    }
    
}
