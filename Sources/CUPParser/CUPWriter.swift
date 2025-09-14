//
//  File.swift
//  CUPParser
//
//  Created by Wouter Wessels on 11/09/2025.
//

import Foundation

public struct CUPWriter {
    public enum Newline: String {
        case lf   = "\n"    // Unix/macOS/iOS
        case crlf = "\r\n"  // Windows / many aviation tools expect this
    }
    
    public init() {}
    
    public func makeCUP(
        waypoints: [CUPWaypoint],
        tasks: [CUPTask],
        newline: Newline = .crlf) -> String {
            var out: [String] = []
            // Standard header (common 11 columns)
            out.append("name,code,country,lat,lon,elev,style,rwdir,rwlen,freq,desc")
            
            for waypoint in waypoints {
                let cols: [String] = [
                    csvAlwaysQuoted(waypoint.title),
                    csvAlwaysQuoted(waypoint.code),
                    csv(waypoint.country ?? ""),
                    formatLatitude(waypoint.latitude),
                    formatLongitude(waypoint.longitude),
                    formatElevation(waypoint.elevationMeters),
                    csv(waypoint.style ?? ""),
                    waypoint.runwayDirection.map { String($0) } ?? "",
                    formatLength(waypoint.runwayLengthMeters),
                    csv(waypoint.frequency ?? ""),
                    csv(waypoint.description ?? "")
                ]
                out.append(cols.joined(separator: ","))
            }
            if !tasks.isEmpty {
                out.append("-----Related Tasks-----")
                for task in tasks {
                    // Ensure names used below exist in waypoints map (Title field)
                    // or supply alternative points (see below).
                    var fields: [String] = []
                    fields.append(csvAlwaysQuoted(task.name))   // description

                    // Takeoff & landing: if you don’t have them, use empty fields ("")
                    // or pick first/last waypoint names. Avoid "???", unless you specifically
                    // want to emulate WeGlide placeholders.
                    let takeoff = "???"
                    let landing = "???"

                    fields.append(csvAlwaysQuoted(takeoff))
                    fields.append(contentsOf: task.waypointNames.map(csvAlwaysQuoted))
                    fields.append(csvAlwaysQuoted(landing))

                    out.append(fields.joined(separator: ","))
                    // If you have options or OZs, write them as additional lines:
                    // out.append("Options,TaskTime=01:45:00,NearDis=0.7km")
                    // out.append("ObsZone=0,Style=2,R1=400m,A1=180,Line=1")
                }
            }
            return out.joined(separator: newline.rawValue) + newline.rawValue
        }
    
    public func write(
        waypoints: [CUPWaypoint],
        tasks: [CUPTask],
        to url: URL,
        newline: Newline = .crlf,
        encoding: String.Encoding = .utf8) throws {
            let text = makeCUP(waypoints: waypoints, tasks: tasks, newline: newline)
            try text.data(using: encoding).map { try $0.write(to: url) }
        }
    
    
    // MARK: - Formatting helpers
    
    private func csvAlwaysQuoted(_ s: String) -> String {
        // Always quote; escape any inner quotes with ""
        return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
    
    private func csv(_ s: String) -> String {
        // Quote only when needed (comma, quote, or leading/trailing space)
        let needsQuoting = s.contains(",") || s.contains("\"") || s.first == " " || s.last == " "
        return needsQuoting ? csvAlwaysQuoted(s) : s
    }
    
    private func formatElevation(_ meters: Double?) -> String {
        guard let m = meters else { return "" }
        return "\(Int((m).rounded()))m"   // e.g. 83m
    }
    
    private func formatLength(_ meters: Double?) -> String {
        guard let m = meters else { return "" }
        let rounded = Int(m.rounded())
        return "\(rounded)"
    }
    
    private func formatLatitude(_ lat: Double) -> String {
        let hemi = lat >= 0 ? "N" : "S"
        let absVal = abs(lat)
        let deg = Int(absVal)
        let minutes = (absVal - Double(deg)) * 60.0
        // Latitude: DDMM.mmmH
        return String(format: "%02d%06.3f%@", deg, minutes, hemi)
    }
    
    private func formatLongitude(_ lon: Double) -> String {
        let hemi = lon >= 0 ? "E" : "W"
        let absVal = abs(lon)
        let deg = Int(absVal)
        let minutes = (absVal - Double(deg)) * 60.0
        // Longitude: DDDMM.mmmH
        return String(format: "%03d%06.3f%@", deg, minutes, hemi)
    }
}
