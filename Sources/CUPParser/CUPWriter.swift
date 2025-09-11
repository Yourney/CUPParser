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
            out.append("Title,Code,Country,Latitude,Longitude,Elevation,Style,RunwayDirection,RunwayLength,Frequency,Description")
            
            for waypoint in waypoints {
                let cols: [String] = [
                    csv(waypoint.title),
                    csv(waypoint.code),
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
                for t in tasks {
                    var cols: [String] = ["Task", csv(t.name)]
                    cols.append(contentsOf: t.waypointCodes.map(csv))
                    out.append(cols.joined(separator: ","))
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
}

// MARK: - Formatting helpers

private func csv(_ string: String) -> String {
    // Double internal quotes and wrap in quotes if the field contains comma, quote, or leading/trailing space
    let needsQuoting = string.contains(",") || string.contains("\"") || string.first == " " || string.last == " "
    if needsQuoting {
        return "\"" + string.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    } else {
        return string
    }
}

private func formatElevation(_ meters: Double?) -> String {
    guard let m = meters else { return "" }
    // CUP usually uses meters for elevation
    let rounded = Int((m).rounded())
    return "\(rounded)m"
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

