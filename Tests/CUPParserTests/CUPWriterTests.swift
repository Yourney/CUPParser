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
        let wps = [
            CUPWaypoint(title: "Biddinghuizen", code: "BIDD", country: "NL", latitude: 52.275, longitude: 5.688, elevationMeters: 2, style: "3", runwayDirection: 90, runwayLengthMeters: 800, frequency: "122.705", description: "Winch field"),
            CUPWaypoint(title: "Lelystad Airport", code: "EHLE", country: "NL", latitude: 52.292, longitude: 5.5167, elevationMeters: 4, style: "4", runwayDirection: 230, runwayLengthMeters: 2700, frequency: "123.905", description: "ATZ")
        ]
        let tasks = [ CUPTask(name: "Local Hop", waypointCodes: ["BIDD", "EHLE"]) ]
        
        let text = CUPWriter().makeCUP(waypoints: wps, tasks: tasks, newline: .lf)
        let doc = try CUPParser().parse(text)
        
        #expect(doc.waypoints.count == 2)
        #expect(doc.tasks.count == 1)
        #expect(doc.tasks.first?.waypointCodes == ["BIDD", "EHLE"])
    }
}
