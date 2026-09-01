//
//  Recording.swift
//  woolone
//
//  Created by Fikrah Damar Huda on 31/08/26.
//

import Foundation

/// A recorded session on disk: its header now, its frames when asked for.
nonisolated struct Recording: Sendable, Identifiable, Equatable {
    let url: URL
    let header: RecordingHeader

    var id: String { url.lastPathComponent }
    var name: String { url.deletingPathExtension().lastPathComponent }

    // only the head is read: the picker needs four headers, not four whole recordings
    init(url: URL) throws {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let head = try handle.read(upToCount: 8192) ?? Data()

        guard let line = String(decoding: head, as: UTF8.self).split(separator: "\n").first,
              let header = RecordingHeader.decode(String(line)) else {
            throw Failure.noHeader(url.lastPathComponent)
        }
        self.url = url
        self.header = header
    }

    /// A half-written last line is skipped, not thrown — a killed recording costs one frame, not the file.
    func frames() throws -> [RecordedFrame] {
        try String(contentsOf: url, encoding: .utf8)
            .split(separator: "\n")
            .dropFirst()
            .compactMap { FrameLine.decode(String($0), header: header) }
    }

    /// Shipped inside the app: replay has to run on the simulator, which has no camera and no Documents.
    static func bundled() -> [Recording] {
        (Bundle.main.urls(forResourcesWithExtension: "ndjson", subdirectory: nil) ?? [])
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { try? Recording(url: $0) }
    }

    enum Failure: Error, CustomStringConvertible {
        case noHeader(String)

        var description: String {
            switch self {
            case .noHeader(let name): "\(name) has no readable header line"
            }
        }
    }
}
