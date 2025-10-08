import Foundation

#if canImport(ZIPFoundation)
import ZIPFoundation
#endif

/// Reads CUP / CUPX files and returns decoded text plus (for CUPX) an assets directory with images.
public struct CUPReader {
    
    // MARK: Public Types
    
    public struct Options {
        /// If true, decoding must succeed without lossy fallbacks; otherwise throws.
        public var strict: Bool
        /// Optional working directory for temporary CUPX extraction. Defaults to Caches/CUPXWork.
        public var workingDirectory: URL?
        
        public init(strict: Bool = true, workingDirectory: URL? = nil) {
            self.strict = strict
            self.workingDirectory = workingDirectory
        }
    }
    
    public enum ChosenEncoding: String {
        case utf8
        case windowsCP1252
        case utf16LE
        case utf16BE
        case utf8Lossy   // only when strict == false
    }
    
    /// Result of reading a CUP or CUPX file.
    public struct ReadResult {
        /// The complete CUP text (for CUPX this is the decoded `POINTS.CUP`).
        public let text: String
        /// Which text encoding was ultimately used.
        public let encoding: ChosenEncoding
        /// For CUPX, a directory that may contain images (e.g., pics/). Nil for plain CUP.
        public let assetsDirectory: URL?
    }
    
    public enum ReadError: Error, LocalizedError {
        case emptyFile
        case cannotDetermineEncoding
        case unzipUnavailable
        case cupxUnsupported(String)
        case missingPointsCup
        
        public var errorDescription: String? {
            switch self {
                case .emptyFile:
                    return "The file is empty."
                case .cannotDetermineEncoding:
                    return "Could not determine text encoding. Re-export as UTF-8 or select Windows-1252."
                case .unzipUnavailable:
                    return "ZIPFoundation is not available on this platform."
                case let .cupxUnsupported(msg):
                    return "CUPX is not recognized: \(msg)"
                case .missingPointsCup:
                    return "POINTS.CUP not found inside the CUPX archive."
            }
        }
    }
    
    // MARK: Init
    
    private let options: Options
    public init(options: Options = .init()) { self.options = options }
    
    // MARK: Public API
    
    /// Read a .cup or .cupx file from disk.
    /// - Returns: Decoded CUP text and (for CUPX) an optional assets directory.
    public func read(fileURL: URL) throws -> ReadResult {
        let ext = fileURL.pathExtension.lowercased()
        if ext == "cupx" {
#if canImport(ZIPFoundation)
            return try readCUPX(fileURL: fileURL)
#else
            throw ReadError.unzipUnavailable
#endif
        } else {
            let data = try Data(contentsOf: fileURL)
            return try decodeText(data: data)
        }
    }
    
    /// Read CUP text from raw bytes (used when you already have Data).
    public func read(data: Data, fileExtension: String? = nil) throws -> ReadResult {
        if fileExtension?.lowercased() == "cupx" {
#if canImport(ZIPFoundation)
            // For completeness: allow passing CUPX data directly.
            // Write to a temp file so we can use unzip routines.
            let tmpDir = try makeWorkingDirectory()
            let tmpURL = tmpDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("cupx")
            try data.write(to: tmpURL, options: .atomic)
            return try readCUPX(fileURL: tmpURL)
#else
            throw ReadError.unzipUnavailable
#endif
        } else {
            return try decodeText(data: data)
        }
    }
    
    // MARK: Decoding (public for tests)
    
    /// Decodes bytes to String using: BOM → UTF-16 heuristics → strict UTF-8 → CP-1252 (+sanity) → lossy (if !strict).
    public func decodeText(data: Data) throws -> ReadResult {
        guard !data.isEmpty else { throw ReadError.emptyFile }
        
        // 1) BOM checks
        if data.starts(with: [0xEF, 0xBB, 0xBF]) {
            let body = data.dropFirst(3)
            return .init(text: String(decoding: body, as: UTF8.self), encoding: .utf8, assetsDirectory: nil)
        }
        if data.starts(with: [0xFF, 0xFE]) {
            if let str = String(data: data.dropFirst(2), encoding: .utf16LittleEndian) {
                return .init(text: str, encoding: .utf16LE, assetsDirectory: nil)
            }
        }
        if data.starts(with: [0xFE, 0xFF]) {
            if let str = String(data: data.dropFirst(2), encoding: .utf16BigEndian) {
                return .init(text: str, encoding: .utf16BE, assetsDirectory: nil)
            }
        }
        
        // 2) UTF-16 without BOM (alternating NULs)
        if looksLikeUTF16LE(data) {
            if let str = String(data: data, encoding: .utf16LittleEndian) {
                return .init(text: str, encoding: .utf16LE, assetsDirectory: nil)
            }
        } else if looksLikeUTF16BE(data) {
            if let str = String(data: data, encoding: .utf16BigEndian) {
                return .init(text: str, encoding: .utf16BE, assetsDirectory: nil)
            }
        }
        
        // 3) Strict UTF-8
        if let utf8 = String(data: data, encoding: .utf8) {
            return .init(text: utf8, encoding: .utf8, assetsDirectory: nil)
        }
        
        // 4) Legacy fallback: CP-1252 (sanity checked)
        if let cp1252 = String(data: data, encoding: .windowsCP1252), looksSaneText(cp1252) {
            return .init(text: cp1252, encoding: .windowsCP1252, assetsDirectory: nil)
        }
        
        // 5) Last resort (only if !strict): lossy UTF-8 decode
        if !options.strict {
            let lossy = String(decoding: data, as: UTF8.self)
            return .init(text: lossy, encoding: .utf8Lossy, assetsDirectory: nil)
        }
        
        throw ReadError.cannotDetermineEncoding
    }
    
    // MARK: CUPX (ZIP) Handling
    
#if canImport(ZIPFoundation)
    private func readCUPX(fileURL: URL) throws -> ReadResult {
        let workRoot = try makeWorkingDirectory()
        let workDir = workRoot.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
        
        // Strategy A: treat .cupx as a single ZIP (most common)
        if try unzipSingleArchiveIfPossible(fileURL: fileURL, to: workDir) {
            // If nested pics.zip exists, unpack it
            if let nestedPics = findFile(namedLike: "pics.zip", under: workDir) {
                try FileManager.default.unzipItem(at: nestedPics, to: workDir)
            }
            // Find POINTS.CUP anywhere
            if let pointsURL = findPointsCup(under: workDir) {
                let data = try Data(contentsOf: pointsURL)
                var result = try decodeText(data: data)
                result = ReadResult(text: result.text, encoding: result.encoding, assetsDirectory: findImagesDirectory(under: workDir))
                return result
            }
            // Fall through to Strategy B
        }
        
        // Strategy B: concatenated ZIPs (points.zip + pics.zip back-to-back)
        let cupxData = try Data(contentsOf: fileURL)
        let segments = splitConcatenatedZips(data: cupxData)
        guard !segments.isEmpty else {
            throw ReadError.cupxUnsupported("No ZIP signatures found.")
        }
        
        for (index, segment) in segments.enumerated() {
            let tmpZip = workDir.appendingPathComponent("segment\(index).zip")
            try segment.write(to: tmpZip)
            try FileManager.default.unzipItem(at: tmpZip, to: workDir)
        }
        
        // Unpack inner points.zip / pics.zip if present
        if let innerPoints = findFile(namedLike: "points.zip", under: workDir) {
            let dir = workDir.appendingPathComponent("points", isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try FileManager.default.unzipItem(at: innerPoints, to: dir)
        }
        if let innerPics = findFile(namedLike: "pics.zip", under: workDir) {
            let dir = workDir.appendingPathComponent("pics", isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try FileManager.default.unzipItem(at: innerPics, to: dir)
        }
        
        guard let pointsCUP = findPointsCup(under: workDir) else {
            throw ReadError.missingPointsCup
        }
        
        let pointsData = try Data(contentsOf: pointsCUP)
        var final = try decodeText(data: pointsData)
        final = ReadResult(text: final.text, encoding: final.encoding, assetsDirectory: findImagesDirectory(under: workDir))
        return final
    }
    
    private func unzipSingleArchiveIfPossible(fileURL: URL, to destination: URL) throws -> Bool {
        do {
            try FileManager.default.unzipItem(at: fileURL, to: destination)
            return true
        } catch {
            return false
        }
    }
#endif
    
    // MARK: Internal Helpers (encoding)
    
    private func looksLikeUTF16LE(_ data: Data) -> Bool {
        let limit = min(data.count, 8_192)
        guard limit >= 4 else { return false }
        var zeroOdd = 0
        var oddTotal = 0
        var idx = 1
        while idx < limit {
            oddTotal += 1
            if data[idx] == 0 { zeroOdd += 1 }
            idx += 2
        }
        let ratio = oddTotal == 0 ? 0.0 : Double(zeroOdd) / Double(oddTotal)
        return ratio > 0.75
    }
    
    private func looksLikeUTF16BE(_ data: Data) -> Bool {
        let limit = min(data.count, 8_192)
        guard limit >= 4 else { return false }
        var zeroEven = 0
        var evenTotal = 0
        var idx = 0
        while idx < limit {
            evenTotal += 1
            if data[idx] == 0 { zeroEven += 1 }
            idx += 2
        }
        let ratio = evenTotal == 0 ? 0.0 : Double(zeroEven) / Double(evenTotal)
        return ratio > 0.75
    }
    
    private func looksSaneText(_ text: String) -> Bool {
        let maxSample = min(text.count, 16_384)
        if maxSample == 0 { return false }
        
        var controlCount = 0
        var newlineSeen = false
        var printableCount = 0
        
        for ch in text.prefix(maxSample) {
            if ch == "\n" || ch == "\r" { newlineSeen = true }
            if ch.isASCII {
                let scalar = ch.unicodeScalars.first!.value
                if scalar < 0x20 && scalar != 9 && scalar != 10 && scalar != 13 {
                    controlCount += 1
                } else {
                    printableCount += 1
                }
            } else {
                printableCount += 1
            }
        }
        let controlRatio = Double(controlCount) / Double(max(1, printableCount))
        if controlRatio > 0.005 { return false }
        if !newlineSeen { return false }
        return true
    }
    
    // MARK: Internal Helpers (filesystem/search)
    
    private func makeWorkingDirectory() throws -> URL {
        if let custom = options.workingDirectory { return custom }
        let caches = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let dir = caches.appendingPathComponent("CUPXWork", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    private func findPointsCup(under root: URL) -> URL? {
        let fm = FileManager.default
        let it = fm.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
        while let item = it?.nextObject() as? URL {
            let name = item.lastPathComponent.lowercased()
            if name == "points.cup" || name.hasSuffix(".cup") {
                return item
            }
        }
        return nil
    }
    
    private func findImagesDirectory(under root: URL) -> URL? {
        let candidates = ["pics", "images", "img", "photos"]
        for name in candidates {
            let dir = root.appendingPathComponent(name, isDirectory: true)
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: dir.path, isDirectory: &isDir), isDir.boolValue {
                return dir
            }
        }
        return nil
    }
    
    private func findFile(namedLike pattern: String, under root: URL) -> URL? {
        let fm = FileManager.default
        let it = fm.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
        while let item = it?.nextObject() as? URL {
            if item.lastPathComponent.lowercased() == pattern.lowercased() {
                return item
            }
        }
        return nil
    }
    
    /// Split a blob into individual ZIP segments by scanning for "PK\x03\x04".
    /// Used for the concatenated CUPX variant (points.zip + pics.zip).
    private func splitConcatenatedZips(data: Data) -> [Data] {
        let sig0: UInt8 = 0x50 // 'P'
        let sig1: UInt8 = 0x4B // 'K'
        let sig2: UInt8 = 0x03
        let sig3: UInt8 = 0x04
        
        var offsets: [Int] = []
        var idx = 0
        while idx <= data.count - 4 {
            if data[idx] == sig0 && data[idx + 1] == sig1 && data[idx + 2] == sig2 && data[idx + 3] == sig3 {
                offsets.append(idx)
            }
            idx += 1
        }
        guard !offsets.isEmpty else { return [] }
        
        var segments: [Data] = []
        for i in 0..<offsets.count {
            let start = offsets[i]
            let end = (i + 1 < offsets.count) ? offsets[i + 1] : data.count
            segments.append(data[start..<end])
        }
        return segments
    }
}
