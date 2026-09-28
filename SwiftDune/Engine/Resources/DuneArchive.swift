//
//  DuneArchive.swift
//  SwiftDune
//
//  Where a game file comes from: a loose file in the bundle's DuneFiles
//  folder (the floppy release), else an entry of DuneFiles/DUNE.DAT (the CD
//  release), extracted once into Caches/DuneArchive so the loaders keep
//  reading plain files. DUNE.DAT: a u16 entry count, then per entry a
//  16-byte name, u32 size, u32 offset and a reserved byte.
//
//  Format from the ScummVM Dune engine's resource.cpp (Desert Frost engine,
//  github.com/AppTesterMC/desert-frost-engine).
//

import Foundation


enum DuneArchive {
    private static let lock = NSLock()
    private static var entries: [String: (offset: UInt64, size: Int)]?

    /// DuneFiles (floppy build) or DuneFilesCD (CD build).
    private static let bundleFolder: URL? = {
        guard let resources = Bundle.main.resourceURL else { return nil }
        for name in ["DuneFiles", "DuneFilesCD"] {
            let url = resources.appendingPathComponent(name, isDirectory: true)
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        return nil
    }()

    private static var archiveURL: URL? {
        guard let folder = bundleFolder else { return nil }
        let url = folder.appendingPathComponent("DUNE.DAT")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// The CD release is present (its data is in DUNE.DAT).
    static var isCD: Bool { archiveURL != nil }

    private static func index() -> [String: (offset: UInt64, size: Int)] {
        lock.lock(); defer { lock.unlock() }
        if let entries = entries { return entries }
        var built: [String: (offset: UInt64, size: Int)] = [:]
        if let url = archiveURL, let handle = try? FileHandle(forReadingFrom: url) {
            defer { try? handle.close() }
            if let head = try? handle.read(upToCount: 2), head.count == 2 {
                let count = Int(head[0]) | Int(head[1]) << 8
                if count > 0 && count <= 4096, let table = try? handle.read(upToCount: count * 25), table.count == count * 25 {
                    let bytes = [UInt8](table)
                    for i in 0..<count {
                        let e = i * 25
                        let nameBytes = bytes[e..<(e + 16)].prefix { $0 != 0 }
                        let name = String(decoding: nameBytes, as: UTF8.self).uppercased()
                        let size = Int(bytes[e + 16]) | Int(bytes[e + 17]) << 8 | Int(bytes[e + 18]) << 16 | Int(bytes[e + 19]) << 24
                        let offset = UInt64(bytes[e + 20]) | UInt64(bytes[e + 21]) << 8 | UInt64(bytes[e + 22]) << 16 | UInt64(bytes[e + 23]) << 24
                        if !name.isEmpty && built[name] == nil { built[name] = (offset, size) }
                    }
                }
            }
        }
        entries = built
        return built
    }

    /// A readable path for the game file `name`, or nil if it exists nowhere.
    static func path(_ name: String) -> String? {
        let upper = name.uppercased()
        if let folder = bundleFolder {
            let loose = folder.appendingPathComponent(upper)
            if FileManager.default.fileExists(atPath: loose.path) { return loose.path }
        }
        guard let entry = index()[upper], let archive = archiveURL else { return nil }
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("DuneArchive", isDirectory: true)
        let target = caches.appendingPathComponent(upper)
        if let attributes = try? FileManager.default.attributesOfItem(atPath: target.path),
           (attributes[.size] as? NSNumber)?.intValue == entry.size {
            return target.path
        }
        do {
            try FileManager.default.createDirectory(at: caches, withIntermediateDirectories: true)
            let handle = try FileHandle(forReadingFrom: archive)
            defer { try? handle.close() }
            try handle.seek(toOffset: entry.offset)
            guard let data = try handle.read(upToCount: entry.size), data.count == entry.size else { return nil }
            try data.write(to: target, options: .atomic)
            return target.path
        } catch {
            DuneEngine.shared.logger.log(.error, "DUNE.DAT: cannot extract \(upper): \(error.localizedDescription)")
            return nil
        }
    }
}
