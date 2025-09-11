//
//  LatLong+CUP.swift
//  CUPParser
//
//  Created by Wouter Wessels on 11/09/2025.
//

import Foundation

enum CUPGeoParseError: Error { case invalidLatitude, invalidLongitude }

/// Converts SeeYou-style lat/long strings to decimal degrees.
/// Examples: "5123.456N", "00345.789E"
func parseCUPLatitude(_ raw: String) throws -> Double {
    // DDMM.MMM[M|N|S]
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let hemi = trimmed.last else { throw CUPGeoParseError.invalidLatitude }
    let body = trimmed.dropLast()
    // Degrees are first 2 chars for latitude
    guard body.count >= 4 else { throw CUPGeoParseError.invalidLatitude }
    let degStr = body.prefix(2)
    let minStr = body.dropFirst(2)
    guard let deg = Int(degStr), let minutes = Double(minStr.replacingOccurrences(of: ",", with: ".")) else {
        throw CUPGeoParseError.invalidLatitude
    }
    var value = Double(deg) + minutes / 60.0
    if hemi == "S" { value = -value }
    return value
}

func parseCUPLongitude(_ raw: String) throws -> Double {
    // DDDMM.MMM[E|W]
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let hemi = trimmed.last else { throw CUPGeoParseError.invalidLongitude }
    let body = trimmed.dropLast()
    // Degrees are first 3 chars for longitude
    guard body.count >= 5 else { throw CUPGeoParseError.invalidLongitude }
    let degStr = body.prefix(3)
    let minStr = body.dropFirst(3)
    guard let deg = Int(degStr), let minutes = Double(minStr.replacingOccurrences(of: ",", with: ".")) else {
        throw CUPGeoParseError.invalidLongitude
    }
    var value = Double(deg) + minutes / 60.0
    if hemi == "W" { value = -value }
    return value
}
