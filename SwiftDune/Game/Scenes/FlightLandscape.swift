//
//  FlightLandscape.swift
//  SwiftDune
//
//  The floppy's ornithopter flight view: DUNES.HSQ dunes and rocks rising
//  from the horizon in perspective, each row of objects seeded from the map
//  cell the route reaches five travel steps ahead, so the pieces follow the
//  terrain actually flown over (sand, rock, vegetation).
//
//  Floppy seg000 routines: setup 4F63, initial fill 57FA (flight branch),
//  row emitter 5982, sprite pickers 5C20, projector 5A8D and scaled blit
//  5B00, per frame 54ED (one frame per 16 ticks), reseed 5BF2, route step
//  5FB7. Ported from the Desert Frost engine (github.com/AppTesterMC/
//  desert-frost-engine, engines/dune/desert.cpp and scene.cpp; research in
//  its notes orni-flight-spec.md §6 and desert-walk-spec.md §3, checked
//  against DOSBox-X captures of the original). The intro keeps Flight.swift.
//

import Foundation


/// A DUNES.HSQ frame: its 6-byte header (width | packed, height, palette
/// base, anchor) and 4-bit pixels, 0 transparent.
private struct LandFrame {
    var width = 0, height = 0, anchor = 0
    var pixels: [UInt8] = []

    init?(_ data: [UInt8], _ frame: Int) {
        guard data.count >= 4 else { return nil }
        func word(_ o: Int) -> Int { Int(data[o]) | Int(data[o + 1]) << 8 }
        let table = word(0)
        guard table + 2 <= data.count else { return nil }
        let count = word(table) / 2
        guard frame < count else { return nil }
        var p = table + word(table + 2 * frame)
        guard p + 6 <= data.count else { return nil }
        let w0 = word(p)
        let packed = w0 & 0x8000 != 0
        width = w0 & 0x1FF
        height = Int(data[p + 2])
        let base = data[p + 3]
        anchor = word(p + 4)
        p += 6
        guard width > 0 && height > 0 && width <= 320 && height <= 200 else { return nil }
        pixels = [UInt8](repeating: 0, count: width * height)
        let rowWidth = (width + 3) & ~3
        for y in 0..<height {
            var x = 0
            while x < rowWidth {
                guard p < data.count else { return }
                var runs = 1
                var fill = false
                var value: UInt8 = 0
                if packed {
                    let r = Int8(bitPattern: data[p]); p += 1
                    fill = r < 0
                    runs = Int(fill ? -Int(r) : Int(r)) + 1
                    if fill {
                        guard p < data.count else { return }
                        value = data[p]; p += 1
                    }
                }
                for _ in 0..<runs {
                    if !fill {
                        guard p < data.count else { return }
                        value = data[p]; p += 1
                    }
                    for nibble in [value & 15, value >> 4] {
                        if x < width && nibble != 0 { pixels[y * width + x] = nibble &+ base }
                        x += 1
                    }
                }
            }
        }
    }
}


final class FlightLandscape: DuneNode {
    private let world = World.shared
    private var sky: Sky?
    private var dunesData: [UInt8] = []
    private var dunesSprite: Sprite?
    private var onmap: Sprite?
    private var icons: Sprite?
    private let fullMap = PixelBuffer(width: 320, height: 152)
    /// The last 23 positions (travel_trail_ring) for the minimap.
    private var trail: [(longitude: UInt16, latitude: Int)] = []
    private var frames: [Int: LandFrame] = [:]

    private struct Object { var z: Int; var x: Int; var sprite: Int }
    private var objects: [Object] = []

    private static let horizon = 77           // ds:20E7
    private static let height = 0x48          // ds:20ED in an ornithopter
    private static let far = 40               // new rows come in at z 40
    private static let groundColour = 0xBF    // the sand below the horizon (3AF8)
    private static let frameSeconds = 0.080   // a frame per 16 ticks (the task at 546D)
    private static let framesPerStep = 8      // a travel step every 8 frames (5CF6)
    // ds:20FD: the eight sets of x positions a row's pieces take.
    private static let xSets: [[Int]] = [
        [-900, -200, 200, 900], [-1300, -400, 0, 1300], [-800, -100, 400, 800], [-600, -300, 100, 600],
        [-1200, -500, 300, 700], [-1000, -50, 500, 1000], [-700, -150, 50, 800], [-1100, -350, 350, 600]
    ]

    /// The route (ds:4 / ds:6): position, the row fraction (0x80 at
    /// take-off), the heading 0-255 and the destination it homes on.
    private var longitude: UInt16 = 0
    private var latitude: Int16 = 0
    private var fraction: UInt8 = 0x80
    private var heading: UInt8 = 0
    private var destination: (longitude: UInt16, latitude: Int16) = (0, 0)
    private var seed: UInt16 = 0
    private var terrain: UInt8 = 0
    private var frameClock: TimeInterval = 0
    /// Frames until the next travel step (0 right after the fill).
    private var stepCountdown = 0
    /// Travel steps flown, and whether the route reached its destination cell.
    private(set) var steps = 0
    private(set) var arrived = false
    var dayMode: DuneLightMode = .day

    // The CD's flight view (travel_select_flight_video, seg000:4ec6): the
    // clips MNT1 sand, MNT2 sand to rock, MNT3 rock, MNT4 rock to sand, the
    // next one chosen from the terrain ahead when a clip ends; no DUNES
    // landscape. One travel step every 0x300 ticks (3.83 s).
    private let isCD = !World.shared.isFloppy
    private var clips: [HnmPlayer] = []
    private var clip = 0
    private var clipClock: TimeInterval = 0
    private var stepClock: TimeInterval = 0
    static let cdStepSeconds = 3.834
    static let clipFrameSeconds = 0.08   // 12.5 frames/s (the DNCDPRG capture)

    init() {
        super.init("FlightLandscape")
    }

    override func onEnable() {
        if isCD {
            clips = ["MNT1.HNM", "MNT2.HNM", "MNT3.HNM", "MNT4.HNM"].compactMap { HnmPlayer($0) }
            clip = 0
            clips.first?.begin()
            clips.first?.step()
        }
        sky = Sky()
        if !isCD {
            // The floppy's landscape sheet (the CD has none: it plays MNT clips).
            dunesData = Resource("DUNES.HSQ").unpackedData
            dunesSprite = Sprite("DUNES.HSQ")
        }
        onmap = Sprite("ONMAP.HSQ")
        icons = Sprite("ICONES.HSQ")
    }

    override func onDisable() {
        sky = nil
        dunesSprite = nil
        clips = []
        onmap = nil
        icons = nil
        objects = []
        trail = []
    }

    /// Params: "from" and "to" as (longitude, latitude) pairs.
    override func onParamsChange() {
        guard let from = params["from"] as? (UInt16, Int), let to = params["to"] as? (UInt16, Int) else { return }
        if let mode = params["dayMode"] as? DuneLightMode { dayMode = mode }
        longitude = from.0
        latitude = Int16(truncatingIfNeeded: from.1)
        fraction = 0x80
        destination = (to.0, Int16(truncatingIfNeeded: to.1))
        steps = 0
        arrived = false
        trail = []
        // Take-off: the first travel step, then the fill (floppy 4F63, 76CA).
        step()
        if isCD {
            stepClock = 0
            clipClock = 0
        } else {
            start()
        }
    }


    // MARK: The route (travel_step_position 7E87, compass 7DB4, heading 7E19)

    /// x86 idiv: the quotient truncated toward zero.
    private static func truncDiv(_ a: Int, _ b: Int) -> Int {
        let q = abs(a) / abs(b)
        return (a >= 0) == (b > 0) ? q : -q
    }

    /// ds:43C7: longitude units per map cell at a latitude.
    private func unitsPerCell(_ latitude: Int) -> Int {
        let cells = world.rowCells(latitude)
        return cells > 0 ? (131072 + cells) / (2 * cells) : 65535
    }

    /// The compass (7DB4): the heading from one position to another, nil
    /// when they coincide.
    private func compassAngle(_ fromLng: UInt16, _ fromLat: Int16, _ toLng: UInt16, _ toLat: Int16) -> UInt8? {
        var bx = Int(Int16(truncatingIfNeeded: Int(toLat) - Int(fromLat)))
        var dx = Int(Int16(bitPattern: toLng &- fromLng))
        if bx < -0x80 || bx >= 0x80 {
            bx >>= 1
            dx >>= 1
        }
        bx = Int(Int16(truncatingIfNeeded: (bx & 0xFF) << 8))
        let ax = abs(bx), cx = abs(dx)
        if cx >= ax {
            guard cx >= 1 else { return nil }
            let al = UInt8(truncatingIfNeeded: FlightLandscape.truncDiv(0x20 * bx, dx))
            return dx >= 0 ? al &+ 0x40 : al &+ 0xC0
        }
        guard ax >= 1 else { return nil }
        var al = UInt8(truncatingIfNeeded: FlightLandscape.truncDiv(0x20 * dx, bx))
        if bx >= 0 { al = al &- 0x80 }
        return 0 &- al
    }

    /// Homing (7E4C): aim at the destination from the current position.
    private func aim() {
        if let angle = compassAngle(longitude, latitude, destination.longitude, destination.latitude) {
            heading = angle
        }
    }

    /// travel_step_position (7E87): one map cell along the heading, the
    /// major axis 0x20, the minor its in-octant share (7E19); the rows go
    /// through the fraction; over a pole the heading turns round.
    private func travelStep(_ lng: inout UInt16, _ lat: inout Int16, _ frac: inout UInt8, _ head: inout UInt8) {
        var cdx: Int, cbx: Int
        let bl = head &+ 0x20
        if bl & 0x7F >= 0x40 {
            var a = head &- 0x40
            cdx = 0x20
            if bl & 0x80 != 0 {
                cdx = -0x20
                a = 0 &- (a &- 0x80)
            }
            cbx = Int(Int8(bitPattern: a))
        } else {
            var a = head
            cbx = -0x20
            if bl & 0x80 != 0 {
                a = 0 &- (a &- 0x80)
                cbx = 0x20
            }
            cdx = Int(Int8(bitPattern: a))
        }
        let bp = unitsPerCell(Int(lat))
        var lngDelta = FlightLandscape.truncDiv(bp * cdx, 0x20)
        let latDelta = FlightLandscape.truncDiv(cbx * bp, 0x20)
        var ax = abs(latDelta) + Int(frac)
        if ax >> 8 > 1 {
            lngDelta = FlightLandscape.truncDiv(lngDelta * 256, ax)
            ax = 0x100
        }
        frac = UInt8(ax & 0xFF)
        var rows = ax >> 8
        if latDelta < 0 { rows = -rows }
        lat = Int16(truncatingIfNeeded: Int(lat) + rows)
        lng = lng &+ UInt16(truncatingIfNeeded: lngDelta)
        if UInt16(bitPattern: lat &+ 0x60) >= 0xC0 {
            head = head &+ 0x80
            lng = lng &+ 0x8000
        }
    }

    /// A real travel step: re-aim, step, record the trail, check arrival.
    private func step() {
        guard !arrived else { return }
        aim()
        trail.append((longitude, Int(latitude)))
        if trail.count > 23 { trail.removeFirst() }
        travelStep(&longitude, &latitude, &fraction, &heading)
        steps += 1
        let here = world.mapCell(longitude: longitude, latitude: Int(latitude))
        let there = world.mapCell(longitude: destination.longitude, latitude: Int(destination.latitude))
        if here != nil && here == there { arrived = true }
    }

    /// The position `count` register-steps ahead (the fraction kept on a
    /// copy, the heading aimed from the current position).
    private func ahead(_ count: Int) -> (UInt16, Int16) {
        var lng = longitude, lat = latitude, frac = fraction
        var head = compassAngle(longitude, latitude, destination.longitude, destination.latitude) ?? heading
        for _ in 0..<count { travelStep(&lng, &lat, &frac, &head) }
        return (lng, lat)
    }


    // MARK: The object engine (57FA, 5982, 5C20, 54ED)

    private func random() -> UInt16 {
        seed = seed &* 0xE56D &+ 1
        return seed
    }

    /// 5963 / 5BF2: the seed and the terrain from a route position.
    private func reseed(_ lng: UInt16, _ lat: Int16) {
        seed = lng ^ UInt16(bitPattern: lat)
        if let cell = world.mapCell(longitude: lng, latitude: Int(lat)), cell < world.map.count {
            terrain = world.map[cell]
        } else {
            terrain = 0
        }
    }

    /// The sprite pickers (5C20): by the terrain's stage bits and height.
    private func pick() -> Int {
        let s = terrain & 0x30, t = terrain & 0x0F
        var h = Int(random() >> 8)
        if s != 0x10 {
            if t <= 8 { return h & 7 }
            if t <= 10 {
                var v = h & 15
                while v > 11 { h = Int(random() >> 8); v = h & 15 }
                return v
            }
            return (h & 3) + 8
        }
        if t <= 8 { return h & 0x80 != 0 ? h & 7 : (h & 3) + 12 }
        if t <= 10 { return h & 15 }
        return (h & 3) + 8 + (seed & 0x8000 != 0 ? 0 : 4)
    }

    /// emit_row (5982): 4 objects at depth z from one of the 8 x-sets.
    private func emitRow(_ z: Int) {
        _ = random()
        let xs = FlightLandscape.xSets[Int((seed >> 8) & 0x38) >> 3]
        for x in xs { objects.append(Object(z: z, x: x, sprite: pick())) }
    }

    /// The initial fill (76CA): five groups of 8 rows, group g at z
    /// 1+8g...8+8g, seeded lng ^ lat at the position g steps ahead.
    private func start() {
        objects = []
        for g in 0..<5 {
            let (lng, lat) = ahead(g)
            reseed(lng, lat)
            for z in (1 + 8 * g)..<(9 + 8 * g) { emitRow(z) }
        }
        frameClock = 0
        stepCountdown = 0
    }

    /// One frame (54ED): every object one step nearer (gone at 0), a row at
    /// z 40 with the current seed; then, every 8 frames starting with the
    /// first, a travel step and a reseed 5 steps ahead of the new position.
    private func tick() {
        objects = objects.compactMap { o in o.z > 1 ? Object(z: o.z - 1, x: o.x, sprite: o.sprite) : nil }
        emitRow(FlightLandscape.far)
        if stepCountdown == 0 {
            step()
            let (lng, lat) = ahead(5)
            reseed(lng, lat)
            stepCountdown = FlightLandscape.framesPerStep
        }
        stepCountdown -= 1
    }

    /// travel_probe_terrain_ahead (seg000:4e8e): the map bytes 6 and 7
    /// steps ahead, averaged whole; the clip choice takes the low nibble.
    private func terrainAhead() -> Int {
        func byte(_ p: (UInt16, Int16)) -> Int {
            guard let c = world.mapCell(longitude: p.0, latitude: Int(p.1)), c < world.map.count else { return 0 }
            return Int(world.map[c])
        }
        return ((byte(ahead(6)) + byte(ahead(7))) / 2) & 0x0F
    }

    private func nextClip() {
        let rock = terrainAhead() >= 8
        if !rock {
            clip = clip == 0 ? 0 : (clip == 1 || clip == 2) ? 3 : 0
        } else {
            clip = (clip == 0 || clip == 3) ? 1 : 2
        }
        clips[clip].begin()
        clips[clip].step()
        engine.logger.log(.info, "Flight view: MNT\(clip + 1) after \(steps) steps (terrain ahead \(terrainAhead()))")
    }

    private func updateCD(_ elapsedTime: TimeInterval) {
        clipClock += elapsedTime
        while clipClock >= FlightLandscape.clipFrameSeconds && !clips.isEmpty {
            clipClock -= FlightLandscape.clipFrameSeconds
            if !clips[clip].step() { nextClip() }
        }
        stepClock += elapsedTime
        while stepClock >= FlightLandscape.cdStepSeconds {
            stepClock -= FlightLandscape.cdStepSeconds
            step()
        }
    }

    override func update(_ elapsedTime: TimeInterval) {
        if isCD {
            updateCD(elapsedTime)
            return
        }
        frameClock += elapsedTime
        var n = 0
        while frameClock >= FlightLandscape.frameSeconds && n < 40 {
            frameClock -= FlightLandscape.frameSeconds
            tick()
            n += 1
        }
    }


    // MARK: Drawing (5A8D, 5B00)

    /// The 1/z table (5A61): 256/z in 8.8 fixed point.
    private static func depthScale(_ z: Int) -> Int {
        let q = 75 / (75 * z), r = 75 % (75 * z)
        return (q << 8) | ((65536 * r / (75 * z)) >> 8)
    }

    private func frame(_ sprite: Int) -> LandFrame? {
        if let f = frames[sprite] { return f }
        let f = LandFrame(dunesData, sprite)
        frames[sprite] = f
        return f
    }

    private func draw(_ o: Object, _ buffer: PixelBuffer) {
        let t = FlightLandscape.depthScale(o.z)
        guard t > 0, let f = frame(o.sprite) else { return }
        let yb = FlightLandscape.horizon + 256 * FlightLandscape.height * t / 65536
        let xl = 160 + o.x * t / 256
        let s = 65536 / t
        let width = 256 * ((f.width + 3) & 0x1FC) / s, frameHeight = 256 * f.height / s
        let top = max(0, yb - 256 * f.anchor / s)
        let raw = buffer.rawPointer
        for y in 0..<frameHeight {
            let sy = top + y, srcY = y * s / 256
            guard sy >= 0 && sy < 152 && srcY < f.height else { continue }
            for dx in 0..<width {
                let sx = xl + dx, srcX = dx * s / 256
                guard sx >= 0 && sx < 320 && srcX < f.width else { continue }
                let v = f.pixels[srcY * f.width + srcX]
                if v != 0 { raw[sy * buffer.width + sx] = v }
            }
        }
    }

    /// The minimap (travel_minimap_setup; ScummVM MapScreen::drawMinimap):
    /// the flat map around Paul in the box (202,3)-(318,61), filled 0xFC
    /// with a 0xFA frame, the trail (ICONES 0x2F) and Paul (0x30).
    private func drawMinimap(_ buffer: PixelBuffer) {
        let renderer = world.mapRenderer
        let lat = Int(latitude)
        let viewLat = min(max(lat - 18, -75), 75)
        fullMap.clearBuffer()
        renderer.draw(fullMap, latitude: viewLat, longitude: longitude)
        let centre = renderer.project(latitude: viewLat, longitude: longitude, placeLatitude: lat, placeLongitude: longitude)
            ?? DunePoint(160, 76)
        let box = (x: 202, y: 3, w: 116, h: 58)
        let w = box.w - 4, h = box.h - 4
        let sx = min(max(Int(centre.x) - w / 2, 4), 316 - w), sy = min(max(Int(centre.y) - h / 2, 4), 148 - h)
        Primitives.fillRect(DuneRect(Int16(box.x), Int16(box.y), UInt16(box.w), UInt8(box.h)), 0xFC, buffer, isOffset: false)
        Primitives.drawLine(DunePoint(Int16(box.x + 1), Int16(box.y + 1)), DunePoint(Int16(box.x + box.w - 2), Int16(box.y + 1)), 0xFA, buffer, isOffset: false)
        Primitives.drawLine(DunePoint(Int16(box.x + 1), Int16(box.y + box.h - 2)), DunePoint(Int16(box.x + box.w - 2), Int16(box.y + box.h - 2)), 0xFA, buffer, isOffset: false)
        Primitives.drawLine(DunePoint(Int16(box.x + 1), Int16(box.y + 1)), DunePoint(Int16(box.x + 1), Int16(box.y + box.h - 2)), 0xFA, buffer, isOffset: false)
        Primitives.drawLine(DunePoint(Int16(box.x + box.w - 2), Int16(box.y + 1)), DunePoint(Int16(box.x + box.w - 2), Int16(box.y + box.h - 2)), 0xFA, buffer, isOffset: false)
        for y in 0..<h {
            for x in 0..<w {
                buffer.rawPointer[(box.y + 2 + y) * buffer.width + box.x + 2 + x] = fullMap.rawPointer[(sy + y) * fullMap.width + sx + x]
            }
        }
        guard let icons = icons else { return }
        for point in trail {
            if let p = renderer.project(latitude: viewLat, longitude: longitude, placeLatitude: point.latitude, placeLongitude: point.longitude) {
                let x = Int(p.x) + box.x + 2 - sx, y = Int(p.y) + box.y + 2 - sy
                if x > box.x + 2 && x < box.x + box.w - 4 && y > box.y + 2 && y < box.y + box.h - 4 {
                    icons.drawFrame(0x2F, x: Int16(x - 1), y: Int16(y - 1), buffer: buffer)
                }
            }
        }
        icons.drawFrame(0x30, x: Int16(Int(centre.x) + box.x + 2 - sx - 1), y: Int16(Int(centre.y) + box.y + 2 - sy - 1), buffer: buffer)
    }


    private func renderCD(_ buffer: PixelBuffer) {
        onmap?.setPalette()                                // the minimap's colours first
        HnmPlayer.applySkyRecord(for: dayMode)             // then SKYDN's record over them
        if !clips.isEmpty { clips[clip].draw(buffer, rows: 152) }
        drawMinimap(buffer)
    }

    override func render(_ buffer: PixelBuffer) {
        if isCD {
            renderCD(buffer)
            return
        }
        guard let sky = sky else { return }
        // ONMAP's palette under the sky's: the minimap's terrain (0x10-0x1F).
        onmap?.setPalette()
        sky.lightMode = dayMode
        sky.render(buffer, width: 320, at: 0, type: .narrow, gameplayPalette: true)
        Primitives.fillRect(DuneRect(0, Int16(FlightLandscape.horizon), 320, UInt8(152 - FlightLandscape.horizon)),
                            FlightLandscape.groundColour, buffer, isOffset: false)
        // The pieces use the sky's colours (the engine sets no DUNES palette
        // in flight). The far rows first: new rows are appended last.
        for o in objects.reversed() { draw(o, buffer) }
        drawMinimap(buffer)
    }
}
