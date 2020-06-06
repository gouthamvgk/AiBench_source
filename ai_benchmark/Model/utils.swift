//
//  utils.swift
//  ai_benchmark
//
//  Created by Goutham Kumar on 03/06/20.
//  Copyright © 2020 Goutham Kumar. All rights reserved.
//

import Foundation


extension FileManager {

    func allocatedSizeOfDirectory(at directoryURL: URL) throws -> String {
        var enumeratorError: Error? = nil
        func errorHandler(_: URL, error: Error) -> Bool {
            enumeratorError = error
            return false
        }

        let enumerator = self.enumerator(at: directoryURL,
                                         includingPropertiesForKeys: Array(allocatedSizeResourceKeys),
                                         options: [],
                                         errorHandler: errorHandler)!

        var accumulatedSize: UInt64 = 0
        for item in enumerator {
            if enumeratorError != nil { break }
            let contentItemURL = item as! URL
            accumulatedSize += try contentItemURL.regularFileAllocatedSize()
        }
        if let error = enumeratorError { throw error }
        return ByteCountFormatter.string(fromByteCount: Int64(accumulatedSize), countStyle: ByteCountFormatter.CountStyle.file)
    }
}


fileprivate let allocatedSizeResourceKeys: Set<URLResourceKey> = [
    .isRegularFileKey,
    .fileAllocatedSizeKey,
    .totalFileAllocatedSizeKey,
]


fileprivate extension URL {
    func regularFileAllocatedSize() throws -> UInt64 {
        let resourceValues = try self.resourceValues(forKeys: allocatedSizeResourceKeys)

        guard resourceValues.isRegularFile ?? false else {
            return 0
        }
        return UInt64(resourceValues.totalFileAllocatedSize ?? resourceValues.fileAllocatedSize ?? 0)
    }
}
