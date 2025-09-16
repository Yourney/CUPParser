import Foundation

// MARK: - Waypoints

public struct CUPWaypoint: Hashable, Codable, Sendable {
    public var title: String
    public var code: String
    public var country: String?
    public var latitude: Double          // decimal degrees
    public var longitude: Double         // decimal degrees
    public var elevationMeters: Double?  // meters
    public var style: String?            // SeeYou style code as string (e.g., "1")
    public var runwayDirection: Int?     // degrees magnetic, 0–359
    public var runwayLengthMeters: Double?
    public var frequency: String?
    public var description: String?

    public init(
        title: String,
        code: String,
        country: String? = nil,
        latitude: Double,
        longitude: Double,
        elevationMeters: Double? = nil,
        style: String? = nil,
        runwayDirection: Int? = nil,
        runwayLengthMeters: Double? = nil,
        frequency: String? = nil,
        description: String? = nil
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

// MARK: - Task Options (from `Options,...` line)

public struct CUPTaskOptions: Hashable, Codable, Sendable {
    /// Local start opening, e.g. "12:30:00"
    public var noStart: String?
    /// Designated AAT time, e.g. "01:45:00"
    public var taskTime: String?
    /// Task distance calculation: false = fixes, true = waypoints
    public var wpDis: Bool?
    /// Distance tolerance (km in many producers)
    public var nearDis: Double?
    /// Altitude tolerance (meters)
    public var nearAlt: Double?
    /// Uncompleted leg distance handling
    public var minDis: Bool?
    /// If true, random order is checked
    public var randomOrder: Bool?
    /// Max number of points
    public var maxPts: Int?
    /// Mandatory waypoints at beginning (1: start only, 2: start + first TP)
    public var beforePts: Int?
    /// Mandatory waypoints at end (1: finish only, 2: finish + one before)
    public var afterPts: Int?
    /// Bonus for crossing the finish
    public var bonus: Int?

    public init(
        noStart: String? = nil,
        taskTime: String? = nil,
        wpDis: Bool? = nil,
        nearDis: Double? = nil,
        nearAlt: Double? = nil,
        minDis: Bool? = nil,
        randomOrder: Bool? = nil,
        maxPts: Int? = nil,
        beforePts: Int? = nil,
        afterPts: Int? = nil,
        bonus: Int? = nil
    ) {
        self.noStart = noStart
        self.taskTime = taskTime
        self.wpDis = wpDis
        self.nearDis = nearDis
        self.nearAlt = nearAlt
        self.minDis = minDis
        self.randomOrder = randomOrder
        self.maxPts = maxPts
        self.beforePts = beforePts
        self.afterPts = afterPts
        self.bonus = bonus
    }
}

// MARK: - Turnpoint
public struct CUPTurnpoint: Hashable, Codable, Sendable {
    public var waypointName: String          // must match CUPWaypoint.title
    public var observationZone: CUPObservationZone? // OZ for this occurrence

    public init(waypointName: String, observationZone: CUPObservationZone? = nil) {
        self.waypointName = waypointName
        self.observationZone = observationZone
    }
}

public struct CUPObservationZone: Hashable, Codable, Sendable {
    public var style: Int
    public var r1Meters: Double?
    public var a1Degrees: Double?
    public var r2Meters: Double?
    public var a2Degrees: Double?
    public var isLine: Bool?

    public init(style: Int,
                r1Meters: Double? = nil,
                a1Degrees: Double? = nil,
                r2Meters: Double? = nil,
                a2Degrees: Double? = nil,
                isLine: Bool? = nil) {
        self.style = style
        self.r1Meters = r1Meters
        self.a1Degrees = a1Degrees
        self.r2Meters = r2Meters
        self.a2Degrees = a2Degrees
        self.isLine = isLine
    }
}


// MARK: - Tasks

public struct CUPTask: Hashable, Codable, Sendable {
    public var name: String

    /// Route: [takeoff, TP1..TPn, landing]
    public var turnpoints: [CUPTurnpoint]

    /// Alternative start names (must match waypoint titles)
    public var starts: [String]?

    /// Task-level options (Options,... line)
    public var options: CUPTaskOptions?

    public init(name: String,
                turnpoints: [CUPTurnpoint],
                starts: [String]? = nil,
                options: CUPTaskOptions? = nil) {
        self.name = name
        self.turnpoints = turnpoints
        self.starts = starts
        self.options = options
    }

    public var waypointNames: [String] { turnpoints.map(\.waypointName) } // convenience
}

// MARK: - Document

public struct CUPDocument: Hashable, Codable, Sendable {
    public var waypoints: [CUPWaypoint]
    public var tasks: [CUPTask]

    public init(waypoints: [CUPWaypoint], tasks: [CUPTask]) {
        self.waypoints = waypoints
        self.tasks = tasks
    }
}
