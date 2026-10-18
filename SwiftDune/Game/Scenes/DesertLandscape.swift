//
//  DesertLandscape.swift
//  SwiftDune
//
//  The desert around Paul on foot: 30 perspective rows of DUNES3 pieces,
//  rocks mirrored where the cells ahead are rock, and a place on this cell
//  within 4 longitude units (DUNES2 frames 0x10–0x17) on the row where the
//  fine position reaches 0.
//

import Foundation


/// A DUNES frame: its 6-byte header and 4-bit pixels, 0 transparent.
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


@MainActor
final class DesertLandscape {
  static let horizon = 77, height = 20, rows = 30, groundColour = 0xBF

  /// The eight sets of x positions a row's pieces take.
  private static let xSets: [[Int]] = [
    [-900, -200, 200, 900], [-1300, -400, 0, 1300], [-800, -100, 400, 800], [-600, -300, 100, 600],
    [-1200, -500, 300, 700], [-1000, -50, 500, 1000], [-700, -150, 50, 800], [-1100, -350, 350, 600]
  ]

  private let dunes3 = Resource("DUNES3.HSQ").unpackedData
  private let dunes2 = Resource("DUNES2.HSQ").unpackedData
  private let paletteSprite = Sprite("DUNES3.HSQ")
  private var frames3: [Int: LandFrame] = [:]
  private var frames2: [Int: LandFrame] = [:]
  private var seed: UInt16 = 0

  private func random() -> UInt16 {
    seed = seed &* 0xE56D &+ 1
    return seed
  }

  /// 256/z in 8.8 fixed point.
  private static func depthScale(_ z: Int) -> Int {
    let q = 75 / (75 * z), r = 75 % (75 * z)
    return (q << 8) | ((65536 * r / (75 * z)) >> 8)
  }

  /// Sprite pick from the terrain's stage bits and height.
  private func pick(_ terrain: UInt8) -> Int {
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

  /// DUNES3's palette over the sky's.
  func setPalette() { paletteSprite.setPalette() }

  func draw(_ buffer: PixelBuffer, longitude: UInt16, latitude: Int, fine: Int, key: UInt16) {
    GameState.shared.prepareWorld()
    let map = GameState.shared.mapState
    let lat = Int16(clamping: latitude)
    let positioned = map.position(x: longitude, lat: lat)
    let cell = map.bytes.indices.contains(positioned.offset) ? positioned.offset : nil
    let terrain: UInt8 = cell.map { map.bytes[$0] } ?? 0
    var rock = false
    if let c = cell {
      for k in -1...4 where map.bytes.indices.contains(c + k) && map.bytes[c + k] & 0x30 == 0x10 { rock = true }
    }
    var building = 0, buildingX = 0, orniCount = 0
    if terrain & 0x40 != 0, let c = cell {
      let locations = GameState.shared.locations
      for i in locations.indices {
        let place = locations[i]
        guard Int(place.mapOffset) == c else { continue }
        let locX = UInt16(bitPattern: place.mapX)
        let d = Int(Int16(bitPattern: locX &- longitude))
        if d >= -4 && d <= 3 {
          buildingX = 512 * d
          let kinds = [17, 16, 18, 19, 19]
          let type = place.appearance
          let kind = type < 0x20 ? 0 : type == 0x20 ? 1 : type < 0x28 ? 2 : type < 0x30 ? 3 : 4
          building = kinds[kind]
          if building >= 0x13 { building = min(0x17, building + Int((type &- 0x28) & 0xFB)) }
          orniCount = 0
        }
        break
      }
    }
    var entries: [(z: Int, x: Int, sprite: Int)] = []
    let bl = Int(UInt8(truncatingIfNeeded: latitude))
    var bh = fine & 0xFF
    var pending = 0
    var z = 1
    while z < DesertLandscape.rows {
      seed = UInt16(truncatingIfNeeded: ((bh << 8) | bl) ^ Int(key)) &+ 0x301
      _ = random()
      let xs = DesertLandscape.xSets[Int((seed >> 8) & 0x38) >> 3]
      if pending != 0 {
        entries.append((z, buildingX, pending))
        pending = 0
      } else {
        for x in xs {
          entries.append((z, x, pick(terrain)))
          if rock { entries.append((z, -x, Int((seed >> 8) & 3) + 0x0C)) }
        }
      }
      z += 1
      bh = (bh - 1) & 0xFF
      if bh == 0 && building != 0 {
        pending = building
        if building != 0x10 && building != 0x12 {
          for k in 0..<orniCount { entries.append((z, buildingX + 0x80 + 32 * (orniCount - 1 - k), 0x18)) }
        }
        building = 0
      }
    }
    for e in entries.reversed() { drawObject(e.sprite, z: e.z, x: e.x, buffer) }
  }

  /// Baseline 77 + 20 T[z] / 256, step 65536 / T[z] (one less for buildings).
  private func drawObject(_ sprite: Int, z: Int, x: Int, _ buffer: PixelBuffer) {
    let t = DesertLandscape.depthScale(z)
    guard t > 0 else { return }
    let fromDunes2 = sprite >= 0x10 && sprite <= 0x17
    let cache = fromDunes2 ? frames2[sprite] : frames3[sprite]
    guard let f = cache ?? LandFrame(fromDunes2 ? dunes2 : dunes3, sprite) else { return }
    if cache == nil { if fromDunes2 { frames2[sprite] = f } else { frames3[sprite] = f } }
    let yb = DesertLandscape.horizon + 256 * DesertLandscape.height * t / 65536
    let xl = 160 + x * t / 256
    var s = 65536 / t
    if sprite >= 0x10 && s > 256 { s -= 256 }
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
}
