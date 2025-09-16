import Foundation

public enum CUPParserError: Error, LocalizedError {
    case headerMissing
    case invalidCoordinate
    case taskContextMissing   // e.g., Options/ObsZone/STARTS before any task line
    case obsZoneIndexOutOfRange(idx: Int, count: Int)

    public var errorDescription: String? {
        switch self {
        case .headerMissing: return "CUP header row is missing."
        case .invalidCoordinate: return "Invalid latitude/longitude format."
        case .taskContextMissing: return "Task-related line found before any task was declared."
        case let .obsZoneIndexOutOfRange(idx, count):
            return "ObsZone index \(idx) is out of bounds for a task with \(count) turnpoints."
        }
    }
}

public struct CUPParser {
    public init() {}

    public func parse(_ text: String) throws -> CUPDocument {
        // Normalize newlines and strip BOM if present
        let normalized = text
            .replacingOccurrences(of: "\u{FEFF}", with: "")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false)

        var waypoints: [CUPWaypoint] = []
        var tasks: [CUPTask] = []

        enum Section { case waypoints, tasks }
        var section: Section = .waypoints

        var headerParsed = false

        for raw in lines {
            let rawLine = raw    // keep Substring for CSV splitter
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }

            if line == "-----Related Tasks-----" {
                section = .tasks
                continue
            }

            switch section {

            // MARK: - WAYPOINTS
            case .waypoints:
                // Skip comments
                if line.hasPrefix("*") { continue }

                if !headerParsed {
                    // Accept any header; we don't need exact names, but we do expect *a* header line.
                    headerParsed = true
                    continue
                }

                let cols = splitCSVLine(rawLine)
                guard cols.count >= 6 else { continue }

                // 0 Title, 1 Code, 2 Country, 3 Lat, 4 Lon, 5 Elevation
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

            // MARK: - TASKS
            case .tasks:
                // 1) Task main line (CSV) — may start with "Task"
                if isTaskMainLine(line) {
                    let cols = splitCSVLine(rawLine)
                    guard !cols.isEmpty else { continue }

                    var nameIndex = 0
                    if cols.first?.caseInsensitiveCompare("Task") == .orderedSame { nameIndex = 1 }
                    guard cols.indices.contains(nameIndex) else { continue }

                    let taskName = cols[nameIndex].isEmpty ? "Unnamed Task" : cols[nameIndex]
                    let names = Array(cols.dropFirst(nameIndex + 1))  // after the name
                    // Build turnpoints from names in order
                    let turnpoints = names.map { CUPTurnpoint(waypointName: $0, observationZone: nil) }

                    tasks.append(CUPTask(
                        name: taskName,
                        turnpoints: turnpoints,
                        starts: nil,
                        options: nil
                    ))
                    continue
                }

                // 2) Options line
                if line.hasPrefix("Options,") || line.hasPrefix("Options,") {
                    guard var last = tasks.popLast() else { throw CUPParserError.taskContextMissing }
                    let options = parseOptionsLine(line)
                    // merge with existing (if any)
                    if var existing = last.options {
                        mergeOptions(&existing, with: options)
                        last.options = existing
                    } else {
                        last.options = options
                    }
                    tasks.append(last)
                    continue
                }

                // 3) ObsZone line
                if line.hasPrefix("ObsZone=") {
                    guard var last = tasks.popLast() else { throw CUPParserError.taskContextMissing }
                    let (idx, oz) = try parseObsZoneLine(line)
                    guard idx >= 0 && idx < last.turnpoints.count else {
                        throw CUPParserError.obsZoneIndexOutOfRange(idx: idx, count: last.turnpoints.count)
                    }
                    var tp = last.turnpoints[idx]
                    tp.observationZone = oz
                    last.turnpoints[idx] = tp
                    tasks.append(last)
                    continue
                }

                // 4) STARTS line
                if line.hasPrefix("STARTS=") {
                    guard var last = tasks.popLast() else { throw CUPParserError.taskContextMissing }
                    last.starts = parseStartsLine(line)
                    tasks.append(last)
                    continue
                }

                // Unknown line in tasks section → ignore (producer-specific extras)
                continue
            }
        }

        guard headerParsed else { throw CUPParserError.headerMissing }
        return CUPDocument(waypoints: waypoints, tasks: tasks)
    }
    
    public func parse(_ data: Data) throws -> CUPDocument {
        let text = self.convertDataToString(data)
        return try parse(text)
    }
    
    private func convertDataToString(_ data: Data) -> String {
        // 1) Strict UTF-8 (fails if not valid)
        if let s = String(data: data, encoding: .utf8) {
            return s
        }
        // 2) Common fallbacks seen in CUP files
        if let s = String(data: data, encoding: .windowsCP1252) { return s }
        if let s = String(data: data, encoding: .isoLatin1)     { return s }
        if let s = String(data: data, encoding: .macOSRoman)    { return s }
        
        // 3) As a last resort, do a lossy UTF-8 decode (never throws but may replace chars)
        return String(decoding: data, as: UTF8.self)
    }
}

// MARK: - Helpers (shared with writer)

fileprivate func emptyToNil(_ s: String?) -> String? {
    guard let s = s else { return nil }
    let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}

fileprivate func parseElevationToMeters(_ s: String?) -> Double? {
    guard let s = s?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
    let lower = s.lowercased()
    if lower.hasSuffix("m"), let v = Double(lower.dropLast()) { return v }
    if lower.hasSuffix("ft"), let v = Double(lower.dropLast(2)) { return v * 0.3048 }
    return Double(lower)
}

fileprivate func parseLengthToMeters(_ s: String?) -> Double? {
    parseElevationToMeters(s)
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - CUP Task lines parsing

fileprivate func isTaskMainLine(_ trimmed: String) -> Bool {
    // Heuristic: CSV line that is not Options/ObsZone/STARTS and either starts with "Task"
    // or starts with a quoted/unquoted name followed by a comma.
    if trimmed.hasPrefix("Options,") { return false }
    if trimmed.hasPrefix("ObsZone=") { return false }
    if trimmed.hasPrefix("STARTS=") { return false }
    // If starts with Task or with a quote/word then comma → likely task line
    if trimmed.lowercased().hasPrefix("task,") { return true }
    // very permissive: treat everything else as task main line first in tasks section
    // but safer to require at least two commas (name + at least takeoff + landing/first TP)
    return trimmed.split(separator: ",").count >= 2
}

// Options,Key=Value,Key=Value,...
fileprivate func parseOptionsLine(_ line: String) -> CUPTaskOptions {
    // Remove leading "Options," (case sensitive in most producers)
    let body = String(line.dropFirst("Options,".count))
    let parts = body.split(separator: ",").map { String($0) }

    var opt = CUPTaskOptions()

    for p in parts {
        guard let eq = p.firstIndex(of: "=") else { continue }
        let key = String(p[..<eq])
        let val = String(p[p.index(after: eq)...])

        switch key.lowercased() {
        case "nostart":       opt.noStart = val
        case "tasktime":      opt.taskTime = val
        case "wpdis":         opt.wpDis = parseBool01(val)
        case "neardis":       opt.nearDis = parseKilometers(val)
        case "nearalt":       opt.nearAlt = parseMeters(val)
        case "mindis":        opt.minDis = parseBool01(val)
        case "randomorder":   opt.randomOrder = parseBool01(val)
        case "maxpts":        opt.maxPts = Int(val)
        case "beforepts":     opt.beforePts = Int(val)
        case "afterpts":      opt.afterPts = Int(val)
        case "bonus":         opt.bonus = Int(val)
        default:              break // ignore unknown keys
        }
    }

    return opt
}

fileprivate func mergeOptions(_ base: inout CUPTaskOptions, with other: CUPTaskOptions) {
    base.noStart      = other.noStart      ?? base.noStart
    base.taskTime     = other.taskTime     ?? base.taskTime
    base.wpDis        = other.wpDis        ?? base.wpDis
    base.nearDis      = other.nearDis      ?? base.nearDis
    base.nearAlt      = other.nearAlt      ?? base.nearAlt
    base.minDis       = other.minDis       ?? base.minDis
    base.randomOrder  = other.randomOrder  ?? base.randomOrder
    base.maxPts       = other.maxPts       ?? base.maxPts
    base.beforePts    = other.beforePts    ?? base.beforePts
    base.afterPts     = other.afterPts     ?? base.afterPts
    base.bonus        = other.bonus        ?? base.bonus
}

// ObsZone=idx,Style=2,R1=400m,A1=180,R2=0m,A2=0,Line=1
fileprivate func parseObsZoneLine(_ line: String) throws -> (index: Int, oz: CUPObservationZone) {
    // Split on commas into key/value pairs; first pair is ObsZone=idx
    let parts = line.split(separator: ",").map { String($0) }
    guard let first = parts.first, first.hasPrefix("ObsZone=") else {
        throw CUPParserError.taskContextMissing
    }
    let idxStr = String(first.dropFirst("ObsZone=".count))
    guard let idx = Int(idxStr) else {
        throw CUPParserError.taskContextMissing
    }

    var style: Int?
    var r1: Double?
    var a1: Double?
    var r2: Double?
    var a2: Double?
    var isLine: Bool?

    for p in parts.dropFirst() {
        guard let eq = p.firstIndex(of: "=") else { continue }
        let key = String(p[..<eq]).lowercased()
        let val = String(p[p.index(after: eq)...])

        switch key {
        case "style": style = Int(val)
        case "r1":    r1 = parseMeters(val)
        case "a1":    a1 = Double(val)
        case "r2":    r2 = parseMeters(val)
        case "a2":    a2 = Double(val)
        case "line":  isLine = parseBool01(val)
        default:      break
        }
    }

    let oz = CUPObservationZone(
        style: style ?? 0,
        r1Meters: r1,
        a1Degrees: a1,
        r2Meters: r2,
        a2Degrees: a2,
        isLine: isLine
    )
    return (idx, oz)
}

// STARTS=Name1,Name2,Name3
fileprivate func parseStartsLine(_ line: String) -> [String] {
    let rhs = String(line.dropFirst("STARTS=".count))
    // Split on commas, trim whitespace, and strip optional surrounding quotes
    return rhs.split(separator: ",").map { piece in
        let s = String(piece).trimmingCharacters(in: .whitespaces)
        return unquoteIfNeeded(s)
    }
}

// MARK: - Tiny parsing utils

fileprivate func parseBool01(_ s: String) -> Bool? {
    let v = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if v == "1" || v == "true" { return true }
    if v == "0" || v == "false" { return false }
    return nil
}

fileprivate func parseMeters(_ s: String) -> Double? {
    let t = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if t.hasSuffix("m") {
        return Double(t.dropLast())
    }
    return Double(t)
}

fileprivate func parseKilometers(_ s: String) -> Double? {
    let t = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if t.hasSuffix("km") {
        return Double(t.dropLast(2))
    }
    return Double(t)
}

/// Remove surrounding quotes if present, and unescape doubled quotes.
fileprivate func unquoteIfNeeded(_ s: String) -> String {
    guard s.first == "\"", s.last == "\"", s.count >= 2 else { return s }
    let inner = s.dropFirst().dropLast()
    return inner.replacingOccurrences(of: "\"\"", with: "\"")
}
