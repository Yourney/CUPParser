//
//  File.swift
//  CUPParser
//
//  Created by Wouter Wessels on 11/09/2025.
//

import Foundation

import Foundation

public struct CUPWriter {
    public enum Newline: String {
        case lf   = "\n"    // Unix/macOS/iOS
        case crlf = "\r\n"  // Many Windows/aviation tools expect this
    }

    public init() {}

    public func makeCUP(
        waypoints: [CUPWaypoint],
        tasks: [CUPTask],
        newline: Newline = .crlf
    ) -> String {
        var out: [String] = []

        // Canonical header
        out.append("Title,Code,Country,Latitude,Longitude,Elevation,Style,RunwayDirection,RunwayLength,Frequency,Description")

        // Waypoints
        for w in waypoints {
            let cols: [String] = [
                csvAlwaysQuoted(w.title),                 // always quoted
                csvAlwaysQuoted(w.code),                  // always quoted
                csv(w.country ?? ""),
                formatLatitude(w.latitude),
                formatLongitude(w.longitude),
                formatElevation(w.elevationMeters),       // e.g. "83m"
                csv(w.style ?? "1"),                      // default "1" if nil
                w.runwayDirection.map(String.init) ?? "",
                formatLength(w.runwayLengthMeters),
                csv(w.frequency ?? ""),
                csv(w.description ?? "")
            ]
            out.append(cols.joined(separator: ","))
        }

        // Tasks
        if !tasks.isEmpty {
            out.append("-----Related Tasks-----")

            for task in tasks {
                // Route as names
                let names = task.turnpoints.map { $0.waypointName }
                let takeoff  = names.first ?? ""
                let landing  = names.last  ?? ""
                let middle   = names.dropFirst().dropLast()

                // Main task line: "Name","Takeoff","TP1",...,"Landing"
                var fields: [String] = []
                fields.append(csvAlwaysQuoted(task.name))
                fields.append(csvAlwaysQuoted(takeoff))
                fields.append(contentsOf: middle.map(csvAlwaysQuoted))
                // Keep landing column even if route is 0/1 long
                fields.append(csvAlwaysQuoted(names.count > 1 ? landing : ""))

                out.append(fields.joined(separator: ","))

                // Options line (if present)
                if let opt = task.options,
                   let line = makeOptionsLine(opt) {
                    out.append(line)
                }

                // One ObsZone line per turnpoint that has an OZ, indexed by position
                for (idx, tp) in task.turnpoints.enumerated() {
                    if let oz = tp.observationZone,
                       let line = makeObsZoneLine(index: idx, oz: oz) {
                        out.append(line)
                    }
                }

                // Multiple starts
                if let starts = task.starts, !starts.isEmpty {
                    // Spec examples show plain names; fall back to quoting if needed
                    let list = starts.map(csvSimpleName).joined(separator: ",")
                    out.append("STARTS=\(list)")
                }
            }
        }

        return out.joined(separator: newline.rawValue) + newline.rawValue
    }

    public func write(
        waypoints: [CUPWaypoint],
        tasks: [CUPTask],
        to url: URL,
        newline: Newline = .crlf,
        encoding: String.Encoding = .utf8
    ) throws {
        let text = makeCUP(waypoints: waypoints, tasks: tasks, newline: newline)
        try text.data(using: encoding)?.write(to: url)
    }

    // MARK: - CSV helpers

    /// Always quote; escape inner quotes with ""
    private func csvAlwaysQuoted(_ s: String) -> String {
        "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    /// Quote only when needed (comma, quote, or leading/trailing space)
    private func csv(_ s: String) -> String {
        let needsQuoting = s.contains(",") || s.contains("\"") || s.first == " " || s.last == " "
        return needsQuoting ? csvAlwaysQuoted(s) : s
    }

    /// For STARTS lists, spec examples show plain names. If unsafe, fall back to quoting.
    private func csvSimpleName(_ s: String) -> String {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty || t.contains(",") || t.contains("\"") {
            return csvAlwaysQuoted(t)
        } else {
            return t
        }
    }

    // MARK: - Field formatters

    private func formatElevation(_ meters: Double?) -> String {
        guard let m = meters else { return "" }
        return "\(Int(m.rounded()))m"
    }

    private func formatLength(_ meters: Double?) -> String {
        guard let m = meters else { return "" }
        return "\(Int(m.rounded()))"
    }

    private func formatLatitude(_ lat: Double) -> String {
        let hemi = lat >= 0 ? "N" : "S"
        let absVal = abs(lat)
        let deg = Int(absVal)
        let minutes = (absVal - Double(deg)) * 60.0
        return String(format: "%02d%06.3f%@", deg, minutes, hemi) // DDMM.mmmH
    }

    private func formatLongitude(_ lon: Double) -> String {
        let hemi = lon >= 0 ? "E" : "W"
        let absVal = abs(lon)
        let deg = Int(absVal)
        let minutes = (absVal - Double(deg)) * 60.0
        return String(format: "%03d%06.3f%@", deg, minutes, hemi) // DDDMM.mmmH
    }

    // MARK: - Options / ObsZone lines

    /// Options,NoStart=12:30:00,TaskTime=01:45:00,WPDis=1,NearDis=0.7km,NearAlt=300m,MinDis=0,...
    private func makeOptionsLine(_ o: CUPTaskOptions) -> String? {
        var parts: [String] = []

        func bool01(_ b: Bool?) -> String? { b.map { $0 ? "1" : "0" } }
        func meters(_ m: Double?) -> String? { m.map { "\(Int($0.rounded()))m" } }
        func km(_ v: Double?) -> String? {
            v.map { value in
                // Keep a compact representation: 0–999 with up to 3 decimals
                let s = String(format: value < 10 ? "%.3f" : (value < 100 ? "%.2f" : "%.1f"), value)
                return s.replacingOccurrences(of: ",", with: ".") + "km"
            }
        }

        if let v = o.noStart     { parts.append("NoStart=\(v)") }
        if let v = o.taskTime    { parts.append("TaskTime=\(v)") }
        if let v = bool01(o.wpDis) { parts.append("WPDis=\(v)") }
        if let v = km(o.nearDis) { parts.append("NearDis=\(v)") }
        if let v = meters(o.nearAlt) { parts.append("NearAlt=\(v)") }
        if let v = bool01(o.minDis) { parts.append("MinDis=\(v)") }
        if let v = bool01(o.randomOrder) { parts.append("RandomOrder=\(v)") }
        if let v = o.maxPts      { parts.append("MaxPts=\(v)") }
        if let v = o.beforePts   { parts.append("BeforePts=\(v)") }
        if let v = o.afterPts    { parts.append("AfterPts=\(v)") }
        if let v = o.bonus       { parts.append("Bonus=\(v)") }

        guard !parts.isEmpty else { return nil }
        return "Options," + parts.joined(separator: ",")
    }

    /// ObsZone=idx,Style=2,R1=400m,A1=180,R2=0m,A2=0,Line=1
    private func makeObsZoneLine(index: Int, oz: CUPObservationZone) -> String? {
        var parts: [String] = []
        func meters(_ m: Double?) -> String? { m.map { "\(Int($0.rounded()))m" } }
        func degrees(_ d: Double?) -> String? { d.map { "\(Int($0.rounded()))" } }

        parts.append("ObsZone=\(index)")
        parts.append("Style=\(oz.style)")
        if let v = meters(oz.r1Meters)   { parts.append("R1=\(v)") }
        if let v = degrees(oz.a1Degrees) { parts.append("A1=\(v)") }
        if let v = meters(oz.r2Meters)   { parts.append("R2=\(v)") }
        if let v = degrees(oz.a2Degrees) { parts.append("A2=\(v)") }
        if let line = oz.isLine          { parts.append("Line=\(line ? "1" : "0")") }

        return parts.joined(separator: ",")
    }
}
