//
//  HnmPlayer.swift
//  SwiftDune
//
//  A streaming decoder for the CD release's HNM videos (the flight views
//  MNT1-4, the arrival clips SIET / PALACE / FORT, ...): a header chunk with
//  the palette, then one chunk per frame whose blocks are sound ("sd"),
//  palette ("pl", which may arrive mid-stream), "pt", "kl", "mm" and one
//  picture (width | 0x0200 HSQ-packed | 0x0400 no position | 0x8000 RLE,
//  height, 0xFF transparent). 160-pixel-wide opaque pictures are shown
//  pixel-doubled.
//
//  Port of the ScummVM Dune engine's hnm.cpp and its HSQ unpacker in
//  resource.cpp (Desert Frost engine, github.com/AppTesterMC/
//  desert-frost-engine). Floppy videos keep using Video.swift.
//

import Foundation


final class HnmPlayer {
    static let width = 320, height = 200

    private var data: [UInt8] = []
    private var offset = 0
    private(set) var frameCount = 0
    /// The picture so far (320 x 200 palette indices).
    private(set) var screen = [UInt8](repeating: 0, count: HnmPlayer.width * HnmPlayer.height)
    /// 256 colours, RGBA packed as the engine's palette expects.
    private(set) var palette = [UInt32](repeating: 0xFF000000, count: 256)
    private var paletteSet = [Bool](repeating: false, count: 256)
    private var scale = 1

    init?(_ name: String) {
        guard let path = DuneArchive.path(name), let file = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
        data = [UInt8](file)
        guard begin() else { return nil }
    }

    private func word(_ o: Int) -> Int { Int(data[o]) | Int(data[o + 1]) << 8 }

    private func readPalette(_ block: Int, _ size: Int, _ position: inout Int) -> Bool {
        while position + 2 <= size {
            let start = Int(data[block + position]), rawCount = Int(data[block + position + 1])
            position += 2
            if start == 0xFF && rawCount == 0xFF { return true }
            if start == 0 && rawCount == 1 {
                position += 3 // the original leaves colour 0 alone
                continue
            }
            let count = rawCount == 0 ? 256 : rawCount
            guard start + count <= 256, position + count * 3 <= size else { return false }
            for i in 0..<count {
                let r = UInt32(data[block + position] & 0x3F) << 2
                let g = UInt32(data[block + position + 1] & 0x3F) << 2
                let b = UInt32(data[block + position + 2] & 0x3F) << 2
                palette[start + i] = 0xFF000000 | b << 16 | g << 8 | r
                paletteSet[start + i] = true
                position += 3
            }
        }
        return false
    }

    /// Back to the first frame.
    @discardableResult
    func begin() -> Bool {
        offset = 0
        frameCount = 0
        scale = 1
        screen = [UInt8](repeating: 0, count: screen.count)
        guard data.count >= 4 else { return false }
        let chunkSize = word(0)
        var position = 2
        guard chunkSize >= 4 && chunkSize <= data.count && readPalette(0, chunkSize, &position) else { return false }
        offset = chunkSize
        return true
    }

    /// Decodes the next picture; false at the end of the video.
    @discardableResult
    func step() -> Bool {
        while offset + 2 <= data.count {
            let chunkSize = word(offset)
            guard chunkSize >= 2 && offset + chunkSize <= data.count else { return false }
            let chunk = offset
            offset += chunkSize
            var position = 2
            while position + 4 <= chunkSize {
                let block = chunk + position
                let tag = (data[block], data[block + 1])
                let blockSize = word(block + 2)
                let isData = [("s", "d"), ("p", "l"), ("p", "t"), ("k", "l"), ("m", "m")].contains {
                    tag.0 == UInt8(ascii: Unicode.Scalar($0.0)!) && tag.1 == UInt8(ascii: Unicode.Scalar($0.1)!)
                }
                if isData {
                    guard blockSize >= 4 && position + blockSize <= chunkSize else { return false }
                    if tag == (UInt8(ascii: "p"), UInt8(ascii: "l")) {
                        var palettePosition = 4
                        _ = readPalette(block, blockSize, &palettePosition)
                    }
                    position += blockSize
                    continue
                }
                guard decodeFrame(block, chunkSize - position) else { return false }
                frameCount += 1
                return true
            }
        }
        return false
    }

    /// The whole video to its last picture (the CD's room backdrops).
    func decodeToEnd() {
        begin()
        while step() {}
    }

    private func decodeFrame(_ block: Int, _ size: Int) -> Bool {
        guard size >= 4 else { return false }
        let header = word(block)
        let width = header & 0x1FF
        let height = Int(data[block + 2])
        let transparent = data[block + 3] == 0xFF
        if width == 0 || height == 0 { return true } // hold the previous picture

        var body = Array(data[(block + 4)..<(block + size)])
        if header & 0x0200 != 0 {
            guard body.count >= 6 else { return false }
            let unpackedSize = Int(body[0]) | Int(body[1]) << 8
            let packedSize = Int(body[3]) | Int(body[4]) << 8
            guard packedSize >= 6 && packedSize <= body.count,
                  let unpacked = HnmPlayer.unpackHSQ(Array(body[6..<packedSize]), unpackedSize) else { return false }
            body = unpacked
        }
        var x = 0, y = 0
        if header & 0x0400 == 0 {
            guard body.count >= 4 else { return false }
            x = Int(body[0]) | Int(body[1]) << 8
            y = Int(body[2]) | Int(body[3]) << 8
            body.removeFirst(4)
        }
        scale = (!transparent && width == HnmPlayer.width / 2) ? 2 : 1
        let rle = header & 0x8000 != 0
        if !rle && body.count < width * height { return false }

        var line = [UInt8](repeating: 0, count: width)
        var position = 0
        for row in 0..<height {
            if rle {
                var column = 0
                while column < width {
                    guard position < body.count else { return false }
                    let command = Int8(bitPattern: body[position]); position += 1
                    var count = Int(command < 0 ? -Int(command) : Int(command)) + 1
                    if command < 0 {
                        guard position < body.count else { return false }
                        let value = body[position]; position += 1
                        while count > 0 && column < width { line[column] = value; column += 1; count -= 1 }
                    } else {
                        guard position + count <= body.count else { return false }
                        for i in 0..<count where column < width { line[column] = body[position + i]; column += 1 }
                        position += count
                    }
                }
            } else {
                for c in 0..<width { line[c] = body[row * width + c] }
            }
            for repeatY in 0..<scale {
                let targetY = (y + row) * scale + repeatY
                guard targetY < HnmPlayer.height else { break }
                for column in 0..<width {
                    let pixel = line[column]
                    if transparent && pixel == 0 { continue }
                    for repeatX in 0..<scale {
                        let targetX = (x + column) * scale + repeatX
                        if targetX < HnmPlayer.width { screen[targetY * HnmPlayer.width + targetX] = pixel }
                    }
                }
            }
        }
        return true
    }

    /// Applies the video's colours to the engine palette (set entries only).
    func applyPalette(skipping range: Range<Int>? = nil) {
        var i = 0
        while i < 256 {
            guard paletteSet[i], !(range?.contains(i) ?? false) else { i += 1; continue }
            var j = i
            while j < 256 && paletteSet[j] && !(range?.contains(j) ?? false) { j += 1 }
            var chunk = Array(palette[i..<j])
            DuneEngine.shared.palette.update(&chunk, start: i, count: j - i)
            i = j
        }
    }

    /// Copies rows 0..<rows of the picture into `buffer`.
    func draw(_ buffer: PixelBuffer, rows: Int = 152) {
        for y in 0..<min(rows, buffer.height) {
            for x in 0..<min(HnmPlayer.width, buffer.width) {
                buffer.rawPointer[y * buffer.width + x] = screen[y * HnmPlayer.width + x]
            }
        }
    }

    /// HSQ (LZ77 with interleaved control bits): the packed body after the
    /// 6-byte header.
    static func unpackHSQ(_ packed: [UInt8], _ size: Int) -> [UInt8]? {
        var out = [UInt8](repeating: 0, count: size)
        var o = 0, p = 0, bits = 0, queue = 0
        func bit() -> Int? {
            if bits == 0 {
                guard p + 2 <= packed.count else { return nil }
                queue = Int(packed[p]) | Int(packed[p + 1]) << 8
                p += 2
                bits = 16
            }
            let b = queue & 1
            queue >>= 1
            bits -= 1
            return b
        }
        func byte() -> Int? {
            guard p < packed.count else { return nil }
            defer { p += 1 }
            return Int(packed[p])
        }
        while true {
            guard let b0 = bit() else { return nil }
            if b0 == 1 {
                guard let literal = byte(), o < size else { return nil }
                out[o] = UInt8(literal); o += 1
                continue
            }
            guard let b1 = bit() else { return nil }
            var count: Int, offset: Int
            if b1 == 1 {
                guard let first = byte(), let second = byte() else { return nil }
                count = first & 7
                offset = ((first >> 3) | (second << 5)) - 0x2000
                if count == 0 {
                    guard let extended = byte() else { return nil }
                    count = extended
                    if count == 0 { break }
                }
            } else {
                guard let c1 = bit(), let c2 = bit(), let distance = byte() else { return nil }
                count = c1 * 2 + c2
                offset = distance - 256
            }
            count += 2
            guard count <= size - o else { return nil }
            var source = o + offset
            guard source >= 0 && source < o else { return nil }
            for _ in 0..<count { out[o] = out[source]; o += 1; source += 1 }
        }
        return o == size ? out : nil
    }
}


extension HnmPlayer {
    /// The CD's clips carry no palette: SKYDN.HSQ's record for the hour
    /// colours them (entry 8 + the sky index: sunrise 16, day 1, sunset 6,
    /// night 3), as it does the room backdrops (ScummVM setVideoSkyPalette,
    /// Sprite::setPaletteRecord: a frame whose first word is 0, start and
    /// count at bytes 4-5, then 6-bit RGB).
    static func applySkyRecord(for lightMode: DuneLightMode) {
        let index: Int
        switch lightMode {
        case .sunrise: index = 16
        case .day: index = 1
        case .sunset: index = 6
        case .night: index = 3
        case .custom(let i, _, _): index = i
        }
        let data = Resource("SKYDN.HSQ").unpackedData
        guard data.count > 4 else { return }
        func word(_ o: Int) -> Int { Int(data[o]) | Int(data[o + 1]) << 8 }
        let table = word(0)
        let entry = 8 + index
        guard table + 2 * entry + 2 <= data.count else { return }
        let position = table + word(table + 2 * entry)
        guard position + 6 <= data.count, word(position) == 0 else { return }
        let start = Int(data[position + 4]), count = Int(data[position + 5])
        guard start + count <= 256, position + 6 + count * 3 <= data.count else { return }
        var chunk = [UInt32](repeating: 0, count: count)
        for i in 0..<count {
            let o = position + 6 + 3 * i
            chunk[i] = 0xFF000000 | UInt32(data[o + 2] & 0x3F) << 18 | UInt32(data[o + 1] & 0x3F) << 10 | UInt32(data[o] & 0x3F) << 2
        }
        DuneEngine.shared.palette.update(&chunk, start: start, count: count)
    }

    private static var lastFrames: [String: [UInt8]] = [:]

    /// The last picture of a clip (decoded once): the CD's outdoor rooms
    /// keep the arrival clip's last frame as their backdrop.
    static func lastFrame(_ name: String) -> [UInt8]? {
        if let cached = lastFrames[name] { return cached }
        guard let player = HnmPlayer(name) else { return nil }
        player.decodeToEnd()
        lastFrames[name] = player.screen
        return player.screen
    }
}
