//
//  MapRenderer.swift
//  SwiftDune
//
//  The flat map of Dune: MAP.HSQ (50,681 cells; low 4 bits terrain, bits 4-5
//  ownership / vegetation stage, bit 6 a place) laid out by TABLAT.BIN (99
//  rows of big-endian offset and half-length). 36 bands of 4 pixels, 312 px
//  wide at (4,4); each cell becomes 4 pixels, blended across and down, and
//  the row edges follow the planet's curve.
//
//  Port of the ScummVM Dune engine's MapRenderer (map.cpp), which ports
//  madmoose's dune-rust map_renderer.rs.
//

import Foundation


final class MapRenderer {
    static let mapSize = 50_681
    static let mapBase = 0x62FC
    static let bands = 196
    static let bandBegin = 5
    static let bandEnd = 191
    static let viewX = 4
    static let viewY = 4
    static let viewWidth = 312
    static let viewRows = 36

    private let map: () -> [UInt8]
    private var tablat: [(offset: Int, length: Int)] = []
    private var buffer = [UInt8](repeating: 0, count: 4096)

    init(map: @escaping () -> [UInt8], tablat data: [UInt8]) {
        self.map = map
        for i in 0..<99 where (i + 1) * 8 <= data.count {
            tablat.append((Int(data[8 * i]) << 8 | Int(data[8 * i + 1]),
                           Int(data[8 * i + 2]) << 8 | Int(data[8 * i + 3])))
        }
    }

    func rowLength(_ row: Int) -> Int {
        let index = row < 99 ? 98 - row : row - 98
        let i = min(max(index, 0), 98)
        return i < tablat.count ? 2 * tablat[i].length : 0
    }

    func rowOffset(_ row: Int) -> Int {
        let index = row < 99 ? 98 - row : row - 98
        let i = min(max(index, 0), 98)
        let offset = i < tablat.count ? tablat[i].offset : 0
        return row < 99 ? MapRenderer.mapBase - offset : MapRenderer.mapBase + offset
    }

    private func mapPixel(_ cells: [UInt8], _ offset: Int) -> Int {
        guard offset >= 0 && offset < cells.count else { return 0 }
        return (((Int(cells[offset]) & 0x0F) << 1) + 1) << 3
    }

    /// Draws the 36 bands starting at `latitude` into `view` (colours
    /// 0x10-0x1F of ONMAP's palette).
    func draw(_ view: PixelBuffer, latitude: Int, longitude: UInt16) {
        let cells = map()
        let top = latitude + 75 + 5
        for i in 0..<MapRenderer.viewRows {
            drawBand(view, cells, band: i, row: top + i, longitude: longitude)
        }
    }

    private func drawBand(_ view: PixelBuffer, _ cells: [UInt8], band: Int, row: Int, longitude: UInt16) {
        guard row >= MapRenderer.bandBegin && row < MapRenderer.bandEnd else { return }
        for i in 0..<buffer.count { buffer[i] = 0 }
        interpolateLine(cells, row: row, longitude: longitude, output: 140)
        interpolateLine(cells, row: row + 1, longitude: longitude, output: 1740)
        interpolateVertically(row)
        postProcess(row)
        let raw = view.rawPointer
        for y in 0..<4 {
            let screenY = MapRenderer.viewY + 4 * band + y
            if screenY >= view.height { break }
            for x in 0..<MapRenderer.viewWidth {
                let b = buffer[y * 400 + x + 160]
                raw[screenY * view.width + MapRenderer.viewX + x] = ((b >> 4) & 0x0F) + 0x10
            }
        }
    }

    private func interpolateLine(_ cells: [UInt8], row: Int, longitude: UInt16, output: Int) {
        let len = rowLength(row)
        let base = rowOffset(row)
        guard len > 0 else { return }
        let rotation = UInt32(longitude) * UInt32(len)
        let subpixel = Int((rotation >> 14) & 3)
        var rotationOffset = Int(rotation >> 16)
        var out = output - subpixel

        var len1 = len
        var len2: Int
        if len1 < 88 {
            out += 2 * (88 - len1)
            rotationOffset -= len1 / 2
            if rotationOffset < 0 { rotationOffset += len1 }
            let len0 = len1
            len1 -= rotationOffset
            len2 = (len0 + 1) - len1
        } else {
            rotationOffset -= 44
            if rotationOffset < 0 { rotationOffset += len1 }
            len1 -= rotationOffset
            len2 = max(0, 88 + 1 - len1)
        }

        var p0 = mapPixel(cells, base + (rotationOffset > 0 ? rotationOffset - 1 : len - 1))
        func emit(_ p1: Int) {
            let d = (p1 - p0) / 4
            for _ in 0..<4 {
                if out >= 0 && out < buffer.count { buffer[out] = UInt8(truncatingIfNeeded: p0) }
                out += 1
                p0 += d
            }
            p0 = p1
        }
        for i in 0..<max(0, len1) { emit(mapPixel(cells, base + i + rotationOffset)) }
        for i in 0..<max(0, len2) { emit(mapPixel(cells, base + i)) }
    }

    private func interpolateVertically(_ row: Int) {
        var l0Length = UInt32(rowLength(row) / 2)
        var l4Length = UInt32(rowLength(row + 1) / 2)
        let south = row >= MapRenderer.bands / 2
        if south { swap(&l0Length, &l4Length) }
        guard l0Length > 0 && l4Length >= l0Length else { return }

        func get(_ i: Int) -> UInt8 { i >= 0 && i < buffer.count ? buffer[i] : 0 }
        func set(_ i: Int, _ v: UInt8) { if i >= 0 && i < buffer.count { buffer[i] = v } }

        for direction in 0..<2 {
            // Right of the centre first, then left of it.
            let step = direction == 0 ? 1 : -1
            var l0 = direction == 0 ? 320 - 4 : 320 - 4 - 1
            var l1 = l0 + 400, l2 = l1 + 400, l3 = l2 + 400, l4 = l3 + 400
            if south {
                swap(&l0, &l4)
                swap(&l1, &l3)
            }
            let err = UInt16(truncatingIfNeeded: ((l4Length - l0Length) << 16) / l0Length)
            let half = err / 2, quarter = err / 4
            let err1 = UInt8(truncatingIfNeeded: (UInt32(quarter) + 0x80) >> 8)
            let err2 = UInt8(truncatingIfNeeded: (UInt32(half) + 0x80) >> 8)
            let err3 = UInt8(truncatingIfNeeded: (UInt32(half) + UInt32(quarter) + 0x80) >> 8)
            var acc1 = err1, acc2 = err2, acc3 = err3
            var acc4 = err

            for _ in 0..<176 {
                let v0 = get(l0); l0 += step
                let v4 = get(l4); l4 += step
                let d = Int8(truncatingIfNeeded: (Int(v4) - Int(v0)) / 4)

                let v1 = UInt8(truncatingIfNeeded: Int(v0) + Int(d))
                set(l1, v1); l1 += step
                if UInt32(acc1) + UInt32(err1) > 0xFF { set(l1, v1); l1 += step }
                acc1 &+= err1

                let v2 = UInt8(truncatingIfNeeded: Int(v1) + Int(d))
                set(l2, v2); l2 += step
                if UInt32(acc2) + UInt32(err2) > 0xFF { set(l2, v2); l2 += step }
                acc2 &+= err2

                let v3 = UInt8(truncatingIfNeeded: Int(v2) + Int(d))
                set(l3, v3); l3 += step
                if UInt32(acc3) + UInt32(err3) > 0xFF { set(l3, v3); l3 += step }
                acc3 &+= err3

                if UInt32(acc4) + UInt32(err) > 0xFFFF { l4 += step }
                acc4 &+= err
            }
        }
    }

    private static let edges: [(Int, Int)] = [
        (138, 18), (119, 37), (107, 49), (97, 59), (89, 67), (81, 75), (74, 82),
        (68, 88), (63, 93), (57, 99), (52, 104), (48, 108), (44, 112), (39, 117),
        (36, 120), (32, 124), (28, 128), (25, 131), (22, 134), (18, 138), (16, 140),
        (13, 143), (11, 145), (8, 148), (5, 151), (3, 153), (2, 154), (1, 155)
    ]
    private static let left: [UInt8] = [0xC0, 0x90, 0x80, 0x70]
    private static let right: [UInt8] = [0x70, 0x80, 0x90, 0xC0]

    /// Masks the row ends near the poles to the planet's curve.
    private func postProcess(_ row: Int) {
        let north = row < MapRenderer.bands / 2
        for i in 0..<4 {
            let index = north ? 4 * (row - MapRenderer.bandBegin) + i : 4 * (MapRenderer.bandEnd - row - 1) + (3 - i)
            guard index >= 0 && index < 28 else { continue }
            let (w, v) = MapRenderer.edges[index]
            var dst = 160 + 400 * i
            if w > 4 { for _ in 0..<(w - 4) { buffer[dst] = 0; dst += 1 } }
            let n = min(4, w)
            for k in 0..<n { buffer[dst] = MapRenderer.left[4 - n + k]; dst += 1 }
            dst += 2 * v
            for k in 0..<n where dst < buffer.count { buffer[dst] = MapRenderer.right[k]; dst += 1 }
            if w > 4 { for _ in 4..<w where dst < buffer.count { buffer[dst] = 0; dst += 1 } }
        }
    }

    /// Screen position of a place on the flat map, nil when out of view.
    func project(latitude: Int, longitude: UInt16, placeLatitude: Int, placeLongitude: UInt16) -> DunePoint? {
        let top = latitude + 75 + 5
        let row = placeLatitude + 75 + 5
        let band = row - top
        guard band >= 0 && band < MapRenderer.viewRows,
              row >= MapRenderer.bandBegin && row < MapRenderer.bandEnd else { return nil }
        let len = rowLength(row)
        guard len > 0 else { return nil }
        let rotation = UInt32(longitude) * UInt32(len)
        let subpixel = Int((rotation >> 14) & 3)
        var out = 140 - subpixel
        var first = Int(rotation >> 16)
        if len < 88 {
            out += 2 * (88 - len)
            first -= len / 2
        } else {
            first -= 44
        }
        if first < 0 { first += len }
        var column = Int((UInt32(placeLongitude) * UInt32(len)) >> 16) - first
        if column < 0 { column += len }
        guard column <= 88 else { return nil }
        let x = MapRenderer.viewX + (out + 4 * column + 2) - 160
        let y = MapRenderer.viewY + 4 * band + 2
        guard x >= 0 && x < 320 else { return nil }
        return DunePoint(Int16(x), Int16(y))
    }

    /// The map point under a tap: (latitude, longitude).
    func unproject(latitude: Int, longitude: UInt16, x: Int, y: Int) -> (Int, UInt16)? {
        let band = (y - MapRenderer.viewY - 2) / 4
        guard band >= 0 && band < MapRenderer.viewRows else { return nil }
        let placeLatitude = latitude + band
        let row = placeLatitude + 75 + 5
        guard row >= MapRenderer.bandBegin && row < MapRenderer.bandEnd else { return nil }
        let len = rowLength(row)
        guard len > 0 else { return nil }
        let rotation = UInt32(longitude) * UInt32(len)
        let subpixel = Int((rotation >> 14) & 3)
        var out = 140 - subpixel
        var first = Int(rotation >> 16)
        if len < 88 {
            out += 2 * (88 - len)
            first -= len / 2
        } else {
            first -= 44
        }
        if first < 0 { first += len }
        let column = (x - MapRenderer.viewX - out - 2 + 160) / 4
        let cell = ((first + column) % len + len) % len
        return (placeLatitude, UInt16((UInt32(cell) << 16) / UInt32(len)))
    }
}
