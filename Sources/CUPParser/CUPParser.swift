import Foundation
import Parsing

public enum CUPParserError: Error, LocalizedError {
    case headerMissing
    case invalidCoordinate
    
    public var errorDescription: String? {
        switch self {
            case .headerMissing: return "CUP header row is missing."
            case .invalidCoordinate: return "Invalid latitude/longitude format."
        }
    }
}

public struct CUPParser {
    public init() {}
    
    public func parse(_ text: String) throws -> CUPDocument {
        // Normalize newlines and strip BOM if present
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false)
        
        var waypoints: [CUPWaypoint] = []
        var tasks: [CUPTask] = []
        
        enum Section { case waypoints, tasks }
        var section: Section = .waypoints
        
        var headerParsed = false
        
        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            
            if line == "-----Related Tasks-----" {
                section = .tasks
                continue
            }
            switch section {
                case .waypoints:
                    // Skip comments
                    if line.hasPrefix("*") { continue }
                    
                    if !headerParsed {
                        // Expect a header row starting with title,code,Country,...
                        headerParsed = true
                        continue
                    }
                    
                    let cols = splitCSVLine(rawLine)
                    guard cols.count >= 6 else { continue }
                    
                    // CUP standard columns (first 12 are common):
                    // 0 Title, 1 Code, 2 Country, 3 Lat, 4 Lon, 5 Elevation (e.g., 123m or 456ft)
                    // 6 Style, 7 RwyDir, 8 RwyLen, 9 Freq, 10 Desc
                    
                    let title = cols[safe: 0] ?? ""
                    let code = cols[safe: 1] ?? ""
                    let country = emptyToNil(cols[safe: 2])
                    
                    guard
                        let latStr = cols[safe: 3],
                        let lonStr = cols[safe: 4]
                    else { continue }
                    
                    let lat = try parseCUPLatitude(latStr)
                    let lon = try parseCUPLongitude(lonStr)
                    
                    let elevationMeters = parseElevationToMeters(cols[safe: 5])
                    let style = emptyToNil(cols[safe: 6])
                    let rwyDir = (cols[safe: 7]).flatMap { Int($0) }
                    let rwyLenMeters = parseLengthToMeters(cols[safe: 8])
                    let freq = emptyToNil(cols[safe: 9])
                    let desc = emptyToNil(cols[safe: 10])
                    
                    waypoints.append(
                        CUPWaypoint(
                            title: title,
                            code: code,
                            country: country,
                            latitude: lat,
                            longitude: lon,
                            elevationMeters: elevationMeters,
                            style: style,
                            runwayDirection: rwyDir,
                            runwayLengthMeters: rwyLenMeters,
                            frequency: freq,
                            description: desc
                        )
                    )
                case .tasks:
                    // Each task line is also CSV. Conventionally: Name, Code1, Code2, ...
                    // Some files may prefix with "Task"; we tolerate that.
                    let cols = splitCSVLine(rawLine)
                    if cols.isEmpty { continue }
                    
                    var nameIndex = 0
                    if cols.first?.lowercased() == "task" { nameIndex = 1 }
                    guard cols.indices.contains(nameIndex) else { continue }
                    
                    let name = cols[nameIndex].isEmpty ? "Unnamed Task" : cols[nameIndex]
                    let names = Array(cols.dropFirst(nameIndex)).filter { !$0.isEmpty }
                    if !names.isEmpty {
                        tasks.append(CUPTask(name: name, waypointNames: names))
                    }
            }
        }
        
        guard headerParsed else { throw CUPParserError.headerMissing }
        return CUPDocument(waypoints: waypoints, tasks: tasks)
    }
}

fileprivate func emptyToNil(_ s: String?) -> String? {
    guard let s = s else { return nil }
    let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}

fileprivate func parseElevationToMeters(_ s: String?) -> Double? {
    guard let s = s?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
    // Examples: "123m", "400ft", or plain number assumed meters
    if s.hasSuffix("m"), let v = Double(s.dropLast()) { return v }
    if s.lowercased().hasSuffix("ft"), let v = Double(s.dropLast(2)) { return v * 0.3048 }
    return Double(s)
}

fileprivate func parseLengthToMeters(_ s: String?) -> Double? {
    // runway length; SeeYou often uses meters
    return parseElevationToMeters(s)
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
