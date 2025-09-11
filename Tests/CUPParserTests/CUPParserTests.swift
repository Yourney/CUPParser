import Foundation
import Testing

@testable import CUPParser

@Suite struct CUPParserTests {
    
    @Test func parsesSimpleWaypointAndTask() throws {
        let cup = """
Title,Code,Country,Latitude,Longitude,Elevation,Style,RunwayDirection,RunwayLength,Frequency,Description
"Biddinghuizen",BIDD,NL,5216.500N,00541.300E,2m,3,090,800,122.705,Winch field
"Lelystad Airport",EHLE,NL,5217.500N,00531.000E,4m,4,230,2700,123.905,ATZ
-----Related Tasks-----
Task, Local Hop, BIDD, EHLE
"Cross Country", BIDD, EHLE
"""
        
        let parsed = try CUPParser().parse(cup)
        #expect(parsed.waypoints.count == 2)
        #expect(parsed.tasks.count == 2)
        
        let biddinghuizen = parsed.waypoints.first { $0.code == "BIDD" }
        #expect(biddinghuizen != nil)
        #expect( approx((biddinghuizen!.latitude  * 1_000).rounded() / 1_000, 52.275, tolerance: 0.001) )
        #expect( approx((biddinghuizen!.longitude * 1_000).rounded() / 1_000,  5.688, tolerance: 0.001) )

        #expect(parsed.tasks[0].waypointCodes == ["BIDD", "EHLE"])
    }
    
    @Test func elevationFeetToMeters() throws {
        let cup = """
Title,Code,Country,Latitude,Longitude,Elevation,Style,RunwayDirection,RunwayLength,Frequency,Description
"Somewhere",SOME,US,3400.000N,11800.000W,1000ft,,,,,
"""
        let parsed = try CUPParser().parse(cup)
        #expect( approx( parsed.waypoints.first!.elevationMeters!, 304.8, tolerance: 0.001 ) )
    }
    
    @Test func quotedCommas() throws {
        let cup = """
Title,Code,Country,Latitude,Longitude,Elevation,Style,RunwayDirection,RunwayLength,Frequency,Description
"Nice, Place",NICE,FR,4312.000N,00716.000E,3m,,,,,"A \"lovely\" coastal town"
"""
        let parsed = try CUPParser().parse(cup)
        #expect(parsed.waypoints.first?.title == "Nice, Place")
        #expect(parsed.waypoints.first?.description == "A \"lovely\" coastal town")
    }
    
    @Test func parsesRealWorldFile() throws {
        let data = try loadCUP("sampleWaypoints")
        let text = String(decoding: data, as: UTF8.self)
        
        let parsed = try CUPParser().parse(text)
        #expect(parsed.waypoints.count == 1392)
    }
    
    @Test func parsesRealWorldTasks() throws {
        let data = try loadCUP("sampleTask")
        let text = String(decoding: data, as: UTF8.self)
        
        let parsed = try CUPParser().parse(text)
        #expect(!parsed.tasks.isEmpty)
        // Optional: print first task for debugging
        if let t = parsed.tasks.first { print("Task:", t.name, t.waypointCodes) }
    }

    @inline(__always)
    private func approx<T: BinaryFloatingPoint>(
        _ value: T,
        _ expected: T,
        tolerance: T
    ) -> Bool {
        // Guard against negative/zero tolerance and include a tiny ULP cushion.
        let tol = max(tolerance, T.ulpOfOne * 8)
        return abs(value - expected) <= tol
    }
    
    private func loadCUP(_ filename: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: filename, withExtension: "cup") else {
            throw NSError(domain: "CUPParserTests", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Missing file: \(filename).cup"])
        }
        return try Data(contentsOf: url)
    }
}
