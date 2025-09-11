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

let text = try String(contentsOf: url, encoding: .utf8)
let doc = try CUPParser().parse(text)

print("Waypoints:", doc.waypoints.count)
print("Tasks:", doc.tasks.count)
```

### Write a `.CUP` file
```swift
import CUPParser

let waypoints = [
    Waypoint(title: "Biddinghuizen", code: "BIDD", country: "NL",
             latitude: 52.275, longitude: 5.688, elevationMeters: 2,
             style: "3", runwayDirection: 90, runwayLengthMeters: 800,
             frequency: "122.705", description: "Winch field")
]
let tasks = [ Task(name: "Local Hop", waypointCodes: ["BIDD"]) ]

let writer = CUPWriter()
let text = writer.makeCUP(waypoints: waypoints, tasks: tasks)
try writer.write(waypoints: waypoints, tasks: tasks, to: url)
```

---

## Contributing
Issues and pull requests are welcome — especially for:
- Observation zone / turnpoint style support
- Additional field parsing & validation
- Performance improvements for very large CUP files

---

## License
MIT – see [LICENSE](LICENSE) for details.
