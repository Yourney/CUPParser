//
//  TestHelpers.swift
//  CUPParser
//
//  Created by Wouter Wessels on 16/09/2025.
//

import Foundation

func loadCUP(_ filename: String) throws -> Data {
    guard let url = Bundle.module.url(forResource: filename, withExtension: "cup") else {
        throw NSError(domain: "CUPParserTests", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "Missing file: \(filename).cup"])
    }
    return try Data(contentsOf: url)
}
