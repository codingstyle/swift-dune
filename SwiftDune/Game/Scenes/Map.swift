//
//  Map.swift
//  SwiftDune
//
//  Flat planet map (vga_draw_map_zoomed).
//

import Foundation

final class Map: DuneNode {
  private let renderer = FlatMapRenderer()
  private var longitude: UInt16 = 0
  private var latitude: Int16 = 0
  private let globeRect = DuneRect(0, 152, 90, 48)

  init() {
    super.init("Map")
  }

  override func onEnable() {
    installPalette()
    let position = GameState.shared.getMapPosition()
    longitude = position.x
    latitude = min(75, max(-75, position.lat))
    
    Menus.shared.show(.mapTroops)
    
    EventManager.uiStateChangedEvent.notify(UIStateEventData(
      leftPanel: .globe,
      rightPanel: .mapDirections
    ))
  }

  override func onClick(_ event: DuneClickEvent) {
    if globeRect.contains(event.point) {
      EventManager.showFreskEvent.notify(ShowFreskEventData())
    }
  }

  override func handleNavigation(_ direction: Int) -> Bool {
    pan(direction)
    return true
  }

  func pan(_ direction: Int) {
    switch direction {
    case 1:
      latitude = max(-75, latitude - 2)
    case 2:
      longitude = longitude &+ 0x0300
    case 3:
      latitude = min(75, latitude + 2)
    case 4:
      longitude = longitude &- 0x0300
    default:
      break
    }
  }

  override func render(_ buffer: PixelBuffer) {
    GameState.shared.prepareWorld()
    
    guard GameState.shared.mapState.ready else { return }
    
    renderer.draw(
      into: buffer,
      map: GameState.shared.mapState.bytes,
      rows: GameState.shared.mapState,
      latitude: latitude,
      longitude: longitude
    )
  }

  private func installPalette() {
    var index = 0
    while index < 256 {
      let source = index * 3
      let color = 0xFF000000
        | (UInt32(GLOBE_MAP_PALETTE[source + 2]) << 16)
        | (UInt32(GLOBE_MAP_PALETTE[source + 1]) << 8)
        | UInt32(GLOBE_MAP_PALETTE[source])
      engine.palette.rawPointer[index] = color
      index += 1
    }
  }
}

private final class FlatMapRenderer {
  private var scratch = [UInt8](repeating: 0, count: 4096)

  func draw(into buffer: PixelBuffer, map: [UInt8], rows: DuneMap, latitude: Int16, longitude: UInt16) {
    let top = UInt16(latitude + 80)
    var band = 0
    while band < 36 {
      drawBand(into: buffer, map: map, rows: rows, band: band, latitude: top &+ UInt16(band), longitude: longitude)
      band += 1
    }
  }

  private func drawBand(into buffer: PixelBuffer, map: [UInt8], rows: DuneMap, band: Int, latitude: UInt16, longitude: UInt16) {
    _ = scratch.withUnsafeMutableBytes { raw in
      memset(raw.baseAddress, 0, raw.count)
    }
    interpolateHorizontal(map: map, rows: rows, y: latitude, longitude: longitude, output: 140)
    interpolateHorizontal(map: map, rows: rows, y: latitude &+ 1, longitude: longitude, output: 1740)
    interpolateVertically(rows: rows, y: latitude)
    shadeEdges(y: latitude)
    copyBand(into: buffer, band: band)
  }

  private func interpolateHorizontal(map: [UInt8], rows: DuneMap, y: UInt16, longitude: UInt16, output: Int) {
    var output = output
    let len = Int(rows.rowLength(y))
    let mapBase = rows.rowOffset(y)
    guard len > 0 else { return }

    let rotation = (UInt32(len) &* UInt32(longitude))
    let subpixel = Int((rotation >> 14) & 0b11)
    var rotationOffset = Int(rotation >> 16)
    output -= subpixel

    var len1 = len
    var len2 = 0
    if len1 < 88 {
      output += 2 * (88 - len1)
      rotationOffset -= len1 / 2
      if rotationOffset < 0 {
        rotationOffset += len1
      }
      let len0 = len1
      len1 -= rotationOffset
      len2 = (len0 + 1) - len1
    } else {
      rotationOffset -= 44
      if rotationOffset < 0 {
        rotationOffset += len1
      }
      len1 -= rotationOffset
      len2 = 89 - len1
      if len2 < 0 {
        len2 = 0
      }
    }

    var previous = Int(readPixel(map, mapBase, rotationOffset - 1))
    var cell = 0
    while cell < len1 {
      let next = Int(readPixel(map, mapBase, cell + rotationOffset))
      writeRun(&output, previous: &previous, next: next)
      cell += 1
    }
    cell = 0
    while cell < len2 {
      let next = Int(readPixel(map, mapBase, cell))
      writeRun(&output, previous: &previous, next: next)
      cell += 1
    }
  }

  private func writeRun(_ output: inout Int, previous: inout Int, next: Int) {
    let step = (next - previous) / 4
    var pixel = previous
    var i = 0
    while i < 4 {
      write(output, UInt8(truncatingIfNeeded: pixel))
      output += 1
      pixel += step
      i += 1
    }
    previous = next
  }

  private func readPixel(_ map: [UInt8], _ mapBase: Int, _ offset: Int) -> UInt8 {
    let index = mapBase &+ offset
    guard map.indices.contains(index) else { return 0 }
    let height = map[index] & 0x0F
    return ((height << 1) &+ 1) << 3
  }

  private func interpolateVertically(rows: DuneMap, y: UInt16) {
    var shortLen = UInt32(rows.rowLength(y) / 2)
    var longLen = UInt32(rows.rowLength(y &+ 1) / 2)
    let south = y >= 98
    if south {
      swap(&shortLen, &longLen)
    }
    guard shortLen > 0, longLen >= shortLen else { return }

    spread(fromCenter: true, south: south, shortLen: shortLen, longLen: longLen)
    spread(fromCenter: false, south: south, shortLen: shortLen, longLen: longLen)
  }

  private func spread(fromCenter: Bool, south: Bool, shortLen: UInt32, longLen: UInt32) {
    var line0 = fromCenter ? 316 : 315
    var line1 = line0 + 400
    var line2 = line1 + 400
    var line3 = line2 + 400
    var line4 = line3 + 400
    if south {
      swap(&line0, &line4)
      swap(&line1, &line3)
    }

    let err = UInt16(truncatingIfNeeded: ((longLen &- shortLen) << 16) / shortLen)
    let half = err / 2
    let quarter = err / 4
    let err1 = UInt8(truncatingIfNeeded: (quarter &+ 0x80) >> 8)
    let err2 = UInt8(truncatingIfNeeded: (half &+ 0x80) >> 8)
    let err3 = UInt8(truncatingIfNeeded: (half &+ quarter &+ 0x80) >> 8)
    var acc1 = err1
    var acc2 = err2
    var acc3 = err3
    var acc4 = err
    let step = fromCenter ? 1 : -1

    var column = 0
    while column < 176 {
      let v0 = read(line0)
      line0 += step
      let v4 = read(line4)
      line4 += step
      let delta = Int8(truncatingIfNeeded: (Int16(v4) &- Int16(v0)) / 4)

      let v1 = UInt8(bitPattern: Int8(bitPattern: v0) &+ delta)
      write(line1, v1)
      line1 += step
      let overflow1 = acc1.addingReportingOverflow(err1)
      acc1 = overflow1.partialValue
      if overflow1.overflow {
        write(line1, v1)
        line1 += step
      }

      let v2 = UInt8(bitPattern: Int8(bitPattern: v1) &+ delta)
      write(line2, v2)
      line2 += step
      let overflow2 = acc2.addingReportingOverflow(err2)
      acc2 = overflow2.partialValue
      if overflow2.overflow {
        write(line2, v2)
        line2 += step
      }

      let v3 = UInt8(bitPattern: Int8(bitPattern: v2) &+ delta)
      write(line3, v3)
      line3 += step
      let overflow3 = acc3.addingReportingOverflow(err3)
      acc3 = overflow3.partialValue
      if overflow3.overflow {
        write(line3, v3)
        line3 += step
      }

      let overflow4 = acc4.addingReportingOverflow(err)
      acc4 = overflow4.partialValue
      if overflow4.overflow {
        line4 += step
      }
      column += 1
    }
  }

  private func shadeEdges(y: UInt16) {
    guard y >= 5, y < 191 else { return }
    let north = y < 98
    var line = 0
    while line < 4 {
      let index = north ? 4 * Int(y &- 5) + line : 4 * Int(190 &- y) + (3 - line)
      if edgeWidths.indices.contains(index) {
        shadeLine(160 + 400 * line, width: Int(edgeWidths[index].0), inset: Int(edgeWidths[index].1))
      }
      line += 1
    }
  }

  private func shadeLine(_ start: Int, width: Int, inset: Int) {
    let leftShade: [UInt8] = [0xC0, 0x90, 0x80, 0x70]
    let rightShade: [UInt8] = [0x70, 0x80, 0x90, 0xC0]
    var dst = start
    if width > 4 {
      var i = 0
      while i < width - 4 {
        write(dst, 0)
        dst += 1
        i += 1
      }
    }
    let shadeCount = min(4, width)
    var i = 0
    while i < shadeCount {
      write(dst, leftShade[4 - shadeCount + i])
      dst += 1
      i += 1
    }
    dst += 2 * inset
    i = 0
    while i < shadeCount {
      write(dst, rightShade[i])
      dst += 1
      i += 1
    }
    if width > 4 {
      var rest = 4
      while rest < width {
        write(dst, 0)
        dst += 1
        rest += 1
      }
    }
  }

  private func copyBand(into buffer: PixelBuffer, band: Int) {
    var y = 0
    while y < 4 {
      let row = 4 + (4 * band) + y
      guard row >= 0, row < buffer.height else {
        y += 1
        continue
      }
      var x = 0
      while x < 312 {
        let sample = read(y * 400 + x + 160)
        buffer.rawPointer[row * buffer.width + x + 4] = (sample >> 4) &+ 0x10
        x += 1
      }
      y += 1
    }
  }

  private func read(_ index: Int) -> UInt8 {
    guard scratch.indices.contains(index) else { return 0 }
    return scratch[index]
  }

  private func write(_ index: Int, _ value: UInt8) {
    guard scratch.indices.contains(index) else { return }
    scratch[index] = value
  }
}

private let edgeWidths: [(UInt8, UInt8)] = [
  (138, 18), (119, 37), (107, 49), (97, 59), (89, 67), (81, 75), (74, 82), (68, 88),
  (63, 93), (57, 99), (52, 104), (48, 108), (44, 112), (39, 117), (36, 120), (32, 124),
  (28, 128), (25, 131), (22, 134), (18, 138), (16, 140), (13, 143), (11, 145), (8, 148),
  (5, 151), (3, 153), (2, 154), (1, 155)
]
