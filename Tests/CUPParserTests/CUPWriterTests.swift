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
    
    @Test func writeOneWayAndParsesBack() throws {
        let wps: [CUPWaypoint] = [
            CUPWaypoint(title: "Ithwiesen", code: "EDVT", country: "DE",
                        latitude: 51.9511167, longitude: 9.66195, elevationMeters: 372,
                        style: "1", runwayDirection: nil, runwayLengthMeters: nil,
                        frequency: nil, description: nil),
            CUPWaypoint(title: "Lelystad Airport", code: "EHLE", country: "NL",
                        latitude: 52.292, longitude: 5.5167, elevationMeters: 4,
                        style: "4", runwayDirection: 230, runwayLengthMeters: 2700,
                        frequency: "123.905", description: "ATZ")
        ]
        
        // Route: takeoff = EDVT, landing = EHLE (no middle TPs)
        let task = CUPTask(
            name: "Local Hop",
            turnpoints: [
                CUPTurnpoint(waypointName: "EDVT"),
                CUPTurnpoint(waypointName: "EHLE")
            ]
        ) .applyingDefaultObservationZones()
        
        let tasks = [task]
        
        let text = CUPWriter().makeCUP(waypoints: wps, tasks: tasks, newline: .lf)
        let doc = try CUPParser().parse(text)
        
        #expect(doc.waypoints.count == 2)
        #expect(doc.tasks.count == 1)
        
        let firstTask = doc.tasks[0]
        #expect(firstTask.name == "Local Hop")
        #expect(firstTask.turnpoints.map(\.waypointName) == ["EDVT", "EHLE"])
        
        let task1Turnpoint1 = firstTask.turnpoints[0]
        #expect(task1Turnpoint1.waypointName == "EDVT")
        #expect(task1Turnpoint1.observationZone?.style == 2)
        #expect(task1Turnpoint1.observationZone?.r1Meters == 1000)
        #expect(task1Turnpoint1.observationZone?.a1Degrees == 180)
        
        let task1Turnpoint2 = firstTask.turnpoints[1]
        #expect(task1Turnpoint2.waypointName == "EHLE")
        #expect(task1Turnpoint2.observationZone?.style == 3)
        #expect(task1Turnpoint2.observationZone?.r1Meters == 1000)
        #expect(task1Turnpoint2.observationZone?.a1Degrees == 180)
        
        // No options/starts/OZ were provided, so they should be nil/empty.
        #expect(firstTask.options == nil)
        #expect(firstTask.starts == nil || firstTask.starts?.isEmpty == true)
    }
    
    @Test func writeRetourAndParsesBack() throws {
        let waypoints: [CUPWaypoint] = [
            CUPWaypoint(title: "Terlet", code: "EHTL", country: "NL",
                        latitude: 52.0572, longitude: 5.9244, elevationMeters: 83,
                        style: "1", runwayDirection: nil, runwayLengthMeters: nil,
                        frequency: nil, description: nil),
            CUPWaypoint(title: "Ithwiesen", code: "EDVT", country: "DE",
                        latitude: 51.9511167, longitude: 9.66195, elevationMeters: 372,
                        style: "1", runwayDirection: nil, runwayLengthMeters: nil,
                        frequency: nil, description: nil),
            CUPWaypoint(title: "Terlet", code: "EHTL", country: "NL",
                        latitude: 52.0572, longitude: 5.9244, elevationMeters: 83,
                        style: "1", runwayDirection: nil, runwayLengthMeters: nil,
                        frequency: nil, description: nil),
        ]
        
        // Route: takeoff = Terlet, turnpoint at Ithwiesen, landing = Terlet
        let task = CUPTask(
            name: "Local Hop",
            turnpoints: [
                CUPTurnpoint(waypointName: "Terlet"),
                CUPTurnpoint(waypointName: "Ithwiesen"),
                CUPTurnpoint(waypointName: "Terlet")
            ]
        ) .applyingDefaultObservationZones()
                
        let text = CUPWriter().makeCUP(waypoints: waypoints, tasks: [task], newline: .lf)
        let doc = try CUPParser().parse(text)
        
        #expect(doc.waypoints.count == 2)
        #expect(doc.tasks.count == 1)
        
        let firstTask = doc.tasks[0]
        #expect(firstTask.name == "Local Hop")
        #expect(firstTask.turnpoints.map(\.waypointName) == ["Terlet", "Ithwiesen", "Terlet"])
        
        let task1Turnpoint1 = firstTask.turnpoints[0]
        #expect(task1Turnpoint1.waypointName == "Terlet")
        #expect(task1Turnpoint1.observationZone?.style == 2)
        #expect(task1Turnpoint1.observationZone?.r1Meters == 1000)
        #expect(task1Turnpoint1.observationZone?.a1Degrees == 180)
        
        let task1Turnpoint2 = firstTask.turnpoints[1]
        #expect(task1Turnpoint2.waypointName == "Ithwiesen")
        #expect(task1Turnpoint2.observationZone?.style == 1)
        #expect(task1Turnpoint2.observationZone?.r1Meters == 2000)
        #expect(task1Turnpoint2.observationZone?.a1Degrees == 45)
        
        let task1Turnpoint3 = firstTask.turnpoints[2]
        #expect(task1Turnpoint3.waypointName == "Terlet")
        #expect(task1Turnpoint3.observationZone?.style == 3)
        #expect(task1Turnpoint3.observationZone?.r1Meters == 1000)
        #expect(task1Turnpoint3.observationZone?.a1Degrees == 180)
        
        // No options/starts/OZ were provided, so they should be nil/empty.
        #expect(firstTask.options == nil)
        #expect(firstTask.starts == nil || firstTask.starts?.isEmpty == true)
    }
}
