//
//  FlatMap.swift
//  SwiftDune
//
//  The flat map (SEE DUNE MAP, and choosing where to fly when leaving a
//  place): MapRenderer's view under ONMAP.HSQ's palette, the four-line
//  frame, one icon per known place, the place popup, and the DUNE MAP box.
//
//  Port of the ScummVM Dune engine's MapScreen (map.cpp) and its map rows
//  (scene.cpp); positions and tap zones from dune-rust's wasm_map.
//

import Foundation


final class FlatMap: DuneNode {
    private let world = World.shared
    private var icons: Sprite?
    private var font: GameFont?

    /// First band's latitude and the centre longitude of the view.
    private(set) var latitude = -4
    private(set) var longitude: UInt16 = 0x1915
    /// Choosing a destination (leaving a place, TAKE AN ORNITHOPTER).
    private(set) var selecting = false
    /// The place tapped, its popup shown.
    private(set) var destination: Int?
    /// A desert point chosen instead of a place (latitude, longitude).
    private(set) var point: (latitude: Int, longitude: UInt16)?
    /// SEE SPICE DENSITY: rings around the known sietches.
    var density = false
    /// The DUNE MAP box shown when the map opens from a room (4,993 ms).
    private var captionUntil: TimeInterval = 0
    /// 320 x 152 place index per pixel, 0xFF = none.
    private var hitIndex = [UInt8](repeating: 0xFF, count: 320 * 152)

    init() {
        super.init("FlatMap")
    }


    override func onEnable() {
        icons = Sprite("ONMAP.HSQ")
        font = GameFont()
        currentTime = 0
    }


    override func onDisable() {
        icons = nil
        font = nil
    }


    override func onParamsChange() {
        if let selecting = params["select"] as? Bool {
            self.selecting = selecting
            destination = nil
            point = nil
            density = false
            captionUntil = (params["caption"] as? Bool ?? false) ? currentTime + 4.993 : 0
            centreOn(world.currentLocation)
        }
    }


    override func update(_ elapsedTime: TimeInterval) {
        currentTime += elapsedTime
    }


    func centreOn(_ index: Int) {
        let l = world.location(index)
        latitude = min(max(Int(l.latitude) - 18, -75), 75)
        longitude = l.longitude
    }


    /// Arrows: longitude += dx * 0x1002, latitude += dy * 12 within +-75.
    func scroll(dx: Int, dy: Int) {
        longitude = longitude &+ UInt16(truncatingIfNeeded: dx * 0x1002)
        latitude = min(max(latitude + dy * 12, -75), 75)
    }


    /// Chooses a desert point directly (dev harness).
    func choosePoint(latitude: Int, longitude: UInt16) {
        destination = nil
        point = (latitude, longitude)
        captionUntil = 0
    }


    /// Chooses a place directly (dev harness).
    func choose(_ index: Int) {
        centreOn(index)
        destination = index
        captionUntil = 0
    }


    /// A tap in the view: the place under it becomes the destination.
    /// Returns true when the tap was on the map.
    func tap(_ point: DunePoint) -> Bool {
        guard point.x >= 0 && point.x < 320 && point.y >= 0 && point.y < 152 else { return false }
        captionUntil = 0
        let index = hitIndex[Int(point.y) * 320 + Int(point.x)]
        destination = index == 0xFF ? nil : Int(index)
        self.point = nil
        if destination == nil && selecting {
            // Choosing where to fly: the open desert under the tap.
            self.point = world.mapRenderer.unproject(latitude: latitude, longitude: longitude,
                                                     x: Int(point.x), y: Int(point.y)).map { ($0.0, $0.1) }
        }
        return true
    }


    override func render(_ buffer: PixelBuffer) {
        guard let icons = icons else { return }

        Primitives.fillRect(DuneRect(0, 0, 320, 152), 0, buffer, isOffset: false)
        // ONMAP carries the map screen's palette (the terrain is 0x10-0x1F).
        icons.setPalette()
        world.mapRenderer.draw(buffer, latitude: latitude, longitude: longitude)

        // Four nested outlines in the panel's light colours (0xFC, FA, F8, F6).
        var colour = 0xFC
        for i in 0..<4 {
            let a = Int16(i), r = Int16(319 - i), b = Int16(151 - i)
            Primitives.drawLine(DunePoint(a, a), DunePoint(r, a), colour, buffer, isOffset: false)
            Primitives.drawLine(DunePoint(a, b), DunePoint(r, b), colour, buffer, isOffset: false)
            Primitives.drawLine(DunePoint(a, a), DunePoint(a, b), colour, buffer, isOffset: false)
            Primitives.drawLine(DunePoint(r, a), DunePoint(r, b), colour, buffer, isOffset: false)
            colour -= 2
        }

        drawVegetation(buffer, icons)
        drawIcons(buffer, icons)
        if let point = point,
           let p = world.mapRenderer.project(latitude: latitude, longitude: longitude,
                                             placeLatitude: point.latitude, placeLongitude: point.longitude) {
            // The destination mark (seg000:49a0): a small cross.
            Primitives.drawLine(DunePoint(p.x - 3, p.y), DunePoint(p.x + 3, p.y), 0xFC, buffer, isOffset: false)
            Primitives.drawLine(DunePoint(p.x, p.y - 3), DunePoint(p.x, p.y + 3), 0xFC, buffer, isOffset: false)
        }
        if let destination = destination {
            drawPopup(buffer, destination)
        } else if currentTime < captionUntil {
            drawInfoBox(buffer)
        }
    }


    /// map_draw_vegetation_marks (seg000:633b): a tuft on every sprouting
    /// cell ((cell & 0x30) == 0x10) in view, ONMAP 0x79 when the next cell
    /// east sprouts too, else 0x78, jittered by the cell's offset.
    private func drawVegetation(_ buffer: PixelBuffer, _ icons: Sprite) {
        let cells = world.map
        for lat in (latitude - 2)...(latitude + MapRenderer.viewRows + 2) where lat >= -98 && lat <= 98 {
            guard let first = world.mapCell(longitude: 0, latitude: lat) else { continue }
            let count = world.rowCells(lat)
            for c in 0..<count {
                let o = first + c
                guard o < cells.count, cells[o] & 0x30 == 0x10 else { continue }
                let lng = UInt16((UInt32(c) << 16) / UInt32(max(1, count)))
                guard var p = world.mapRenderer.project(latitude: latitude, longitude: longitude,
                                                        placeLatitude: lat, placeLongitude: lng) else { continue }
                let eastToo = o + 1 < cells.count && cells[o + 1] & 0x30 == 0x10
                p.x += Int16(o & 3) - 2
                p.y += Int16((o >> 2) & 3) - 2
                guard p.x >= 4 && p.x <= 312 && p.y >= 4 && p.y <= 144 else { continue }
                icons.drawFrame(eastToo ? 0x79 : 0x78, x: p.x - 4, y: p.y - 4, buffer: buffer)
            }
        }
    }


    private func drawIcons(_ buffer: PixelBuffer, _ icons: Sprite) {
        for i in 0..<hitIndex.count { hitIndex[i] = 0xFF }
        for i in 0..<world.locationCount {
            let l = world.location(i)
            guard !l.hidden,
                  let p = world.mapRenderer.project(latitude: latitude, longitude: longitude,
                                                     placeLatitude: Int(l.latitude), placeLongitude: l.longitude) else { continue }
            if density && l.isSietch && l.spiceDensity > 0 {
                // ONMAP 133-140: eight rings, one per 32 of density (the
                // original's scale is not decoded).
                let ring = UInt16(133 + min(7, Int(l.spiceDensity) / 32))
                icons.drawFrame(ring, x: p.x - 9, y: p.y - 9, buffer: buffer)
            }
            // ONMAP 122-126: sietch, Atreides palace, village, fortress,
            // Harkonnen palace.
            let frame = UInt16(122 + l.kind)
            let info = icons.frame(at: Int(frame))
            let left = Int(p.x) - Int(info.width) / 2, top = Int(p.y) - Int(info.height) / 2
            icons.drawFrame(frame, x: Int16(left), y: Int16(top), buffer: buffer)
            for py in max(0, top)..<min(152, top + Int(info.height)) {
                for px in max(0, left)..<min(320, left + Int(info.width)) where hitIndex[py * 320 + px] == 0xFF {
                    hitIndex[py * 320 + px] = UInt8(i)
                }
            }
        }
    }


    /// The place's panel beside its icon: the kind ("Sietch:", COMMAND
    /// 0x44-0x47) over the name, on black in a frame (seg000:600e).
    private func drawPopup(_ buffer: PixelBuffer, _ index: Int) {
        guard let font = font else { return }
        let l = world.location(index)
        guard let p = world.mapRenderer.project(latitude: latitude, longitude: longitude,
                                                placeLatitude: Int(l.latitude), placeLongitude: l.longitude) else { return }
        let kinds = ["Sietch:", "Palace:", "Village:", "Fort:"]
        let kind = l.type < 0x20 ? 0 : (l.type == 0x20 || l.type == 0x30) ? 1 : l.type < 0x28 ? 2 : 3
        let kindText = GameText.shared.findCommand(kinds[kind]).map { GameText.shared.command($0) } ?? kinds[kind]
        var x = Int(p.x) + 15
        if x > 210 { x = Int(p.x) - 130 }
        x = min(max(x, 4), 316 - 106)
        let y = min(max(Int(p.y) - 15, 4), 148 - 30)
        Primitives.fillRect(DuneRect(Int16(x), Int16(y), 106, 30), 0, buffer, isOffset: false)
        let frame = 0xF5
        Primitives.drawLine(DunePoint(Int16(x), Int16(y)), DunePoint(Int16(x + 105), Int16(y)), frame, buffer, isOffset: false)
        Primitives.drawLine(DunePoint(Int16(x), Int16(y + 29)), DunePoint(Int16(x + 105), Int16(y + 29)), frame, buffer, isOffset: false)
        Primitives.drawLine(DunePoint(Int16(x), Int16(y)), DunePoint(Int16(x), Int16(y + 29)), frame, buffer, isOffset: false)
        Primitives.drawLine(DunePoint(Int16(x + 105), Int16(y)), DunePoint(Int16(x + 105), Int16(y + 29)), frame, buffer, isOffset: false)
        font.paletteIndex = 243
        font.render(kindText, rect: DuneRect(Int16(x + 10), Int16(y + 3), 90, 10), buffer: buffer, alignment: .left, style: .small)
        font.paletteIndex = 250
        font.render(world.locationName(index, GameText.shared.command),
                    rect: DuneRect(Int16(x + 4), Int16(y + 15), 100, 10), buffer: buffer, alignment: .left, style: .small)
    }


    /// COMMAND 213 in a box (10,10)-(190,64), fill 0xFB, frame 0xF5; the
    /// first number is the rallied troops (ds:28).
    private func drawInfoBox(_ buffer: PixelBuffer) {
        guard let font = font else { return }
        Primitives.fillRect(DuneRect(10, 10, 180, 54), 0xFB, buffer, isOffset: false)
        Primitives.drawLine(DunePoint(10, 10), DunePoint(189, 10), 0xF5, buffer, isOffset: false)
        Primitives.drawLine(DunePoint(10, 63), DunePoint(189, 63), 0xF5, buffer, isOffset: false)
        Primitives.drawLine(DunePoint(10, 10), DunePoint(10, 63), 0xF5, buffer, isOffset: false)
        Primitives.drawLine(DunePoint(189, 10), DunePoint(189, 63), 0xF5, buffer, isOffset: false)
        var text = GameText.shared.command(213)
        if let range = text.range(of: "[0-9]+", options: .regularExpression) {
            text.replaceSubrange(range, with: "\(min(999, Int(world.b(0x28))))")
        }
        font.paletteIndex = 243
        font.render(text, rect: DuneRect(20, 16, 164, 44), buffer: buffer, alignment: .left, style: .small)
    }


    /// Flat-map arrow zones (dune-rust wasm_map.click): up, right, down,
    /// left; the centre (tested last) recentres on Paul.
    static func arrow(at point: DunePoint) -> (dx: Int, dy: Int)? {
        let x = Int(point.x), y = Int(point.y)
        if x >= 267 && x < 284 && y >= 162 && y < 171 { return (0, -1) }
        if x >= 285 && x < 297 && y >= 171 && y < 184 { return (1, 0) }
        if x >= 267 && x < 284 && y >= 184 && y < 193 { return (0, 1) }
        if x >= 254 && x < 266 && y >= 171 && y < 184 { return (-1, 0) }
        if x >= 266 && x < 285 && y >= 171 && y < 184 { return (0, 0) }
        return nil
    }
}
