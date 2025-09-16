//
//  Test.swift
//  CUPParser
//
//  Created by Wouter Wessels on 11/09/2025.
//

import Foundation
import Testing
@testable import CUPParser

@Suite struct CUPWriterTests {
    @Test func writesAndParsesBack() throws {
        let wps: [CUPWaypoint] = [
            CUPWaypoint(title: "Biddinghuizen", code: "BIDD", country: "NL",
                        latitude: 52.275, longitude: 5.688, elevationMeters: 2,
                        style: "3", runwayDirection: 90, runwayLengthMeters: 800,
                        frequency: "122.705", description: "Winch field"),
            CUPWaypoint(title: "Lelystad Airport", code: "EHLE", country: "NL",
                        latitude: 52.292, longitude: 5.5167, elevationMeters: 4,
                        style: "4", runwayDirection: 230, runwayLengthMeters: 2700,
                        frequency: "123.905", description: "ATZ")
        ]

        // Route: takeoff = BIDD, landing = EHLE (no middle TPs)
        let task = CUPTask(
            name: "Local Hop",
            turnpoints: [
                CUPTurnpoint(waypointName: "BIDD"),
                CUPTurnpoint(waypointName: "EHLE")
            ]
        )
        let tasks = [task]

        let text = CUPWriter().makeCUP(waypoints: wps, tasks: tasks, newline: .lf)
        let doc = try CUPParser().parse(text)

        #expect(doc.waypoints.count == 2)
        #expect(doc.tasks.count == 1)

        let parsed = doc.tasks[0]
        #expect(parsed.name == "Local Hop")
        #expect(parsed.turnpoints.map(\.waypointName) == ["BIDD", "EHLE"])

        // No options/starts/OZ were provided, so they should be nil/empty.
        #expect(parsed.options == nil)
        #expect(parsed.starts == nil || parsed.starts?.isEmpty == true)
    }
}
