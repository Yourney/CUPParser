//
//  CSV.swift
//  CUPParser
//
//  Created by Wouter Wessels on 11/09/2025.
//

func splitCSVLine(_ line: Substring) -> [String] {
    let s = String(line)
    var fields: [String] = []
    var field = String()
    var insideQuotes = false

    let chars = Array(s)
    var i = 0
    let n = chars.count

    func isSpace(_ c: Character) -> Bool { c == " " || c == "\t" }

    while i < n {
        let ch = chars[i]

        if insideQuotes {
            if ch == "\"" {
                // Case 1: RFC 4180 escape: "" → "
                if i + 1 < n, chars[i + 1] == "\"" {
                    field.append("\"")
                    i += 2
                    continue
                }
                // Case 2: Look ahead — is this a *closing* quote?
                var j = i + 1
                while j < n, isSpace(chars[j]) { j += 1 } // allow spaces between closing quote and comma
                if j == n || chars[j] == "," {
                    // This quote ends the field
                    insideQuotes = false
                    i += 1
                    continue
                } else {
                    // Not followed by comma/EOL → treat as a literal stray quote (permissive)
                    field.append("\"")
                    i += 1
                    continue
                }
            } else {
                field.append(ch)
                i += 1
                continue
            }
        } else {
            if ch == "\"" {
                insideQuotes = true // opening quote
                i += 1
                continue
            } else if ch == "," {
                fields.append(field.trimmingCharacters(in: .whitespaces))
                field.removeAll(keepingCapacity: true)
                i += 1
                continue
            } else {
                field.append(ch)
                i += 1
                continue
            }
        }
    }

    fields.append(field.trimmingCharacters(in: .whitespaces))
    return fields
}
