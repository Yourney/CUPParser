import Foundation
import Testing

@testable import CUPParser

@Suite struct CUPParserTests {
    
    @Test func parsesWeGlideStyleTask() throws {
            let cup = """
            name,code,country,lat,lon,elev,style,rwdir,rwlen,freq,desc
            "Terlet",,,5203.432N,00555.464E,83m,1,,,,
            "Ithwiesen",,,5157.067N,00939.717E,372m,1,,,,
            -----Related Tasks-----
            "500km_560043","???","Terlet","Ithwiesen","Terlet","???"
            """

            let doc = try CUPParser().parse(cup)

            // Waypoints
            #expect(doc.waypoints.count == 2)
            let terlet = doc.waypoints.first { $0.title == "Terlet" }
            let ithwiesen = doc.waypoints.first { $0.title == "Ithwiesen" }
            #expect(terlet != nil && ithwiesen != nil)

            // Lat/Lon checks
            #expect(abs((terlet!.latitude  - 52.0572))  <= 0.0001)  // 52°03.432' N
            #expect(abs((terlet!.longitude -  5.9244))  <= 0.0001)  // 5°55.464' E
            #expect(abs((ithwiesen!.latitude  - 51.9511167)) <= 0.0001) // 51°57.067' N
            #expect(abs((ithwiesen!.longitude -  9.66195))   <= 0.0001) // 9°39.717' E

            // Elevation (meters)
            #expect(abs((terlet!.elevationMeters ?? .nan)    -  83.0) <= 0.001)
            #expect(abs((ithwiesen!.elevationMeters ?? .nan) - 372.0) <= 0.001)

            // Tasks
            #expect(doc.tasks.count == 1)
            let task = doc.tasks[0]
            #expect(task.name == "500km_560043")

            // WeGlide-style placeholders for TO/Landing plus TP names
            #expect(task.waypointNames == ["500km_560043", "???", "Terlet", "Ithwiesen", "Terlet", "???"])
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
        if let t = parsed.tasks.first { print("Task:", t.name, t.waypointNames) }
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
