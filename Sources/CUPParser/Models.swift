//
//  Models.swift
//  CUPParser
//
//  Created by Wouter Wessels on 11/09/2025.
//

import Foundation

public struct CUPWaypoint: Hashable, Codable, Sendable {
    public var title: String
    public var code: String
    public var country: String?
    public var latitude: Double // decimal degrees
    public var longitude: Double // decimal degrees
    public var elevationMeters: Double? // normalized to meters
    public var style: String?
    public var runwayDirection: Int?
    public var runwayLengthMeters: Double?
    public var frequency: String?
    public var description: String?
    
    public init(
        title: String,
        code: String,
        country: String?,
        latitude: Double,
        longitude: Double,
        elevationMeters: Double?,
        style: String?,
        runwayDirection: Int?,
        runwayLengthMeters: Double?,
        frequency: String?,
        description: String?
    ) {
        self.title = title
        self.code = code
        self.country = country
        self.latitude = latitude
        self.longitude = longitude
        self.elevationMeters = elevationMeters
        self.style = style
        self.runwayDirection = runwayDirection
        self.runwayLengthMeters = runwayLengthMeters
        self.frequency = frequency
        self.description = description
    }
}

public struct CUPTask: Hashable, Codable, Sendable {
    public var name: String
    public var waypointNames: [String]
    
    public init(name: String, waypointNames: [String]) {
        self.name = name
        self.waypointNames = waypointNames
    }
}

public struct CUPDocument: Hashable, Codable, Sendable {
    public var waypoints: [CUPWaypoint]
    public var tasks: [CUPTask]
    
    public init(waypoints: [CUPWaypoint], tasks: [CUPTask]) {
        self.waypoints = waypoints
        self.tasks = tasks
    }
}
