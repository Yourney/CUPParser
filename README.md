# CUPParser

A tiny Swift library to **parse and write** Naviter SeeYou `.CUP` waypoint & task files.

- ✅ Parses waypoints (title, code, country, lat/long, elevation, style, runway info, etc.)
- ✅ Parses tasks after the `-----Related Tasks-----` separator
- ✅ Writes `.CUP` files with correct CSV quoting and lat/long formatting
- ✅ Unit tests using **Swift Testing**

---

## Requirements
- **Library:** Swift 5.7+ · iOS 13+ / macOS 11+ / tvOS 13+ / watchOS 6+ / macCatalyst 13+

- **Tests:** Swift 6 / Xcode 16 (Swift Testing)

---

## Installation (Swift Package Manager)

Add to your `Package.swift`:

```swift
.package(url: "https://github.com/Yourney/CUPParser.git", from: "0.1.0-alpha")
```

Or in Xcode: **File → Add Packages…** and paste the repo URL.

---

## Quick Start

### Parse a `.CUP` file
```swift
import CUPParser

let cupText: String = ... // contents of a .cup file
let doc = try CUPParser().parse(cupText)

// Access results
print(doc.waypoints.count)
print(doc.tasks.first?.name ?? "No tasks")
```

### Write a `.CUP` file
```swift
import CUPParser

let waypoints: [CUPWaypoint] = [
    CUPWaypoint(title: "Terlet", code: "EHTL", country: "NL",
                latitude: 52.0572, longitude: 5.9244, elevationMeters: 83,
                style: "1", runwayDirection: nil, runwayLengthMeters: nil,
                frequency: nil, description: nil),
    CUPWaypoint(title: "Ithwiesen", code: "EDVT", country: "DE",
                latitude: 51.9511167, longitude: 9.66195, elevationMeters: 372,
                style: "1", runwayDirection: nil, runwayLengthMeters: nil,
                frequency: nil, description: nil),
    // (Same waypoint can appear multiple times in the route)
    CUPWaypoint(title: "Terlet", code: "EHTL", country: "NL",
                latitude: 52.0572, longitude: 5.9244, elevationMeters: 83,
                style: "1", runwayDirection: nil, runwayLengthMeters: nil,
                frequency: nil, description: nil),
]

// Route: takeoff from Terlet, turnpoint at Ithwiesen, landing at Terlet
var task = CUPTask(
    name: "Local Hop",
    turnpoints: [
        CUPTurnpoint(waypointName: "Terlet"),
        CUPTurnpoint(waypointName: "Ithwiesen"),
        CUPTurnpoint(waypointName: "Terlet")
    ]
)

// (Optional) add observation zones per turnpoint occurrence
task.turnpoints[0].observationZone = CUPObservationZone(style: 2, r1Meters: 1000, a1Degrees: 180)
task.turnpoints[1].observationZone = CUPObservationZone(style: 1, r1Meters: 2000, a1Degrees: 45)
task.turnpoints[2].observationZone = CUPObservationZone(style: 3, r1Meters: 1000, a1Degrees: 180)

// (Optional) task options and multiple starts
task.options = CUPTaskOptions(taskTime: "01:45:00")
task.starts  = ["Terlet"] // names must match waypoint titles

// Write the file contents (CRLF by default; use .lf for Unix)
let cupFileContents = CUPWriter().makeCUP(
    waypoints: waypoints,
    tasks: [task],
    newline: .lf
)
```

---

## Contributing
Issues and pull requests are welcome
- Bug reports and feature requests
- Performance improvements for very large CUP files
- Additional test cases
---

## License
MIT – see [LICENSE](LICENSE) for details.
