//
//  SceneNavigation.swift
//  SwiftDune
//
//  Room exits and desert steps from the DOS scene table.
//

import Foundation

enum DunePlaceKind {
  case palace
  case sietch
  case village
  case fort
  case harkonnenPalace
  case desert
}

struct DuneLocationView {
  var kind: DunePlaceKind
  var salRoom: Int
  var directions: UIDirection
  var indoors: Bool
}

private let desertStepDeltas: [UInt16] = [0x0209, 0xFF00, 0x0001, 0x0100, 0x00FF, 0x0000]

private let sceneDispatch: [UInt8] = [
  12, 14, 16, 18, 20, 22, 25, 28,
  31, 35, 39, 43, 47, 51, 55, 59,
  63, 14, 16, 18, 20, 22, 25, 28,
  31, 35, 39, 43, 47, 51, 55, 59,
  0, 68, 68, 68, 68, 68, 68, 68,
  69, 72, 75, 78, 69, 72, 75, 78,
  81,
]

private let sceneRecords: [(background: UInt8, exits: (UInt8, UInt8, UInt8, UInt8))] = [
  (0x4c, (0x02, 0x00, 0xfd, 0x00)),
  (0x3a, (0x07, 0x00, 0x01, 0x8c)),
  (0xcf, (0x00, 0x00, 0x00, 0x0b)),
  (0x62, (0x0a, 0x00, 0x07, 0x00)),
  (0x4b, (0x00, 0x00, 0x00, 0x0a)),
  (0x15, (0x0b, 0x00, 0x00, 0x00)),
  (0x5d, (0x04, 0x8b, 0x02, 0x88)),
  (0x26, (0x00, 0x87, 0x0c, 0x00)),
  (0x63, (0x00, 0x00, 0x0a, 0x00)),
  (0x61, (0x09, 0x05, 0x04, 0x00)),
  (0x64, (0x00, 0x83, 0x06, 0x07)),
  (0x5e, (0x08, 0x02, 0x00, 0x00)),
  (0x01, (0x02, 0xfe, 0xfd, 0xfc)),
  (0x72, (0x00, 0x00, 0x01, 0x00)),
  (0x01, (0x02, 0xfe, 0xfd, 0xfc)),
  (0x73, (0x00, 0x00, 0x01, 0x00)),
  (0x01, (0x02, 0xfe, 0xfd, 0xfc)),
  (0x74, (0x00, 0x00, 0x01, 0x00)),
  (0x01, (0x02, 0xfe, 0xfd, 0xfc)),
  (0x75, (0x00, 0x00, 0x01, 0x00)),
  (0x01, (0x02, 0xfe, 0xfd, 0xfc)),
  (0x76, (0x00, 0x00, 0x01, 0x00)),
  (0x01, (0x02, 0xfe, 0xfd, 0xfc)),
  (0x77, (0x03, 0x00, 0x01, 0x00)),
  (0x72, (0x00, 0x00, 0x02, 0x00)),
  (0x01, (0x03, 0xfe, 0xfd, 0xfc)),
  (0x78, (0x00, 0x00, 0x03, 0x00)),
  (0x7b, (0x02, 0x00, 0x01, 0x00)),
  (0x01, (0x02, 0xfe, 0xfd, 0xfc)),
  (0x7a, (0x03, 0x00, 0x01, 0x00)),
  (0x72, (0x00, 0x00, 0x02, 0x00)),
  (0x01, (0x03, 0xfe, 0xfd, 0xfc)),
  (0x79, (0x04, 0x00, 0x03, 0x00)),
  (0x7b, (0x02, 0x00, 0x01, 0x00)),
  (0x7d, (0x00, 0x00, 0x02, 0x00)),
  (0x01, (0x03, 0xfe, 0xfd, 0xfc)),
  (0x7c, (0x04, 0x00, 0x03, 0x00)),
  (0x7b, (0x02, 0x00, 0x01, 0x00)),
  (0x7d, (0x00, 0x00, 0x02, 0x00)),
  (0x01, (0x03, 0xfe, 0xfd, 0xfc)),
  (0x74, (0x04, 0x00, 0x03, 0x00)),
  (0x7b, (0x02, 0x00, 0x01, 0x00)),
  (0x7d, (0x00, 0x00, 0x02, 0x00)),
  (0x01, (0x02, 0xfe, 0xfd, 0xfc)),
  (0x75, (0x04, 0x03, 0x01, 0x00)),
  (0x72, (0x00, 0x00, 0x00, 0x02)),
  (0x7d, (0x00, 0x00, 0x02, 0x00)),
  (0x01, (0x02, 0xfe, 0xfd, 0xfc)),
  (0x76, (0x03, 0x00, 0x01, 0x00)),
  (0x73, (0x04, 0x00, 0x02, 0x00)),
  (0x7d, (0x00, 0x00, 0x03, 0x00)),
  (0x01, (0x02, 0xfe, 0xfd, 0xfc)),
  (0x77, (0x03, 0x04, 0x01, 0x00)),
  (0x72, (0x00, 0x00, 0x02, 0x00)),
  (0x7d, (0x00, 0x00, 0x00, 0x02)),
  (0x01, (0x03, 0xfe, 0xfd, 0xfc)),
  (0x78, (0x04, 0x00, 0x03, 0x00)),
  (0x7b, (0x02, 0x00, 0x01, 0x00)),
  (0x7d, (0x00, 0x00, 0x02, 0x00)),
  (0x01, (0x02, 0xfe, 0xfd, 0xfc)),
  (0x7a, (0x03, 0x04, 0x01, 0x00)),
  (0x72, (0x00, 0x00, 0x02, 0x00)),
  (0x7d, (0x00, 0x00, 0x00, 0x02)),
  (0x01, (0x03, 0xfe, 0xfd, 0xfc)),
  (0x7c, (0x05, 0x00, 0x03, 0x00)),
  (0x7b, (0x02, 0x00, 0x01, 0x00)),
  (0x7d, (0x00, 0x05, 0x00, 0x00)),
  (0xde, (0x00, 0x00, 0x02, 0x04)),
  (0x01, (0xff, 0xfe, 0xfd, 0xfc)),
  (0x01, (0x02, 0xfe, 0xfd, 0xfc)),
  (0xa7, (0x00, 0x03, 0x01, 0x00)),
  (0xa6, (0x00, 0x00, 0x00, 0x02)),
  (0x02, (0x02, 0xfe, 0xfd, 0xfc)),
  (0xa7, (0x00, 0x00, 0x01, 0x03)),
  (0xa6, (0x00, 0x02, 0x00, 0x00)),
  (0x03, (0x02, 0xfe, 0xfd, 0xfc)),
  (0xa7, (0x00, 0x03, 0x01, 0x00)),
  (0xa6, (0x00, 0x00, 0x00, 0x02)),
  (0x04, (0x02, 0xfe, 0xfd, 0xfc)),
  (0xa7, (0x00, 0x00, 0x01, 0x03)),
  (0xa6, (0x00, 0x02, 0x00, 0x00)),
  (0x05, (0x02, 0xfe, 0xfd, 0xfc)),
  (0xa8, (0x00, 0x00, 0x01, 0x00)),
]

extension GameState {
  mutating func prepareWorld() {
    guard !mapState.ready else { return }
    mapState.load()
    guard mapState.ready else { return }

    var placed = locations
    var index = 0
    while index < placed.count {
      let snapped = mapState.snap(x: UInt16(bitPattern: placed[index].mapX), lat: placed[index].mapY)
      placed[index].mapX = Int16(bitPattern: snapped.x)
      placed[index].mapOffset = UInt16(truncatingIfNeeded: snapped.offset)
      mapState.markLocation(at: snapped.offset)
      index += 1
    }
    locations = placed
  }

  func getMapPosition() -> (x: UInt16, lat: Int16) {
    if locationAppearance & 0xFF == 0x80, locations.indices.contains(Int(currentLocationIndex)) {
      let location = locations[Int(currentLocationIndex)]
      return (UInt16(bitPattern: location.mapX), location.mapY)
    }
    let lat = Int16(Int8(bitPattern: UInt8(truncatingIfNeeded: locationAppearance)))
    return (locationAndRoom, lat)
  }

  mutating func locationView() -> DuneLocationView {
    prepareWorld()
    if locationAppearance & 0xFF != 0x80 {
      return DuneLocationView(kind: .desert, salRoom: 0, directions: .all, indoors: false)
    }
    let appearance = currentAppearance()
    return DuneLocationView(
      kind: placeKind(appearance),
      salRoom: currentSalRoom(),
      directions: compassDirections(),
      indoors: true
    )
  }

  mutating func move(_ direction: Int) {
    prepareWorld()
    guard direction >= 1, direction <= 4 else { return }

    if locationAppearance & 0xFF != 0x80 {
      let steps = min((desertStepCounter & 0x7F) &+ 1, 0x7F)
      desertStepCounter = steps | 0x80
      if desertExhaustionCounter < 20 {
        desertExhaustionCounter &+= 1
      }
      stepDesert(direction, locationAndRoom, locationAppearance)
      return
    }

    guard let exit = exitByte(direction) else { return }
    if exit == 0 { return }
    if exit & 0x80 != 0 {
      walkOut(exit)
      return
    }

    let newRoom = (locationAndRoom & 0xFF00) | UInt16(exit)
    markVisitedIfNeeded()
    pendingDestinationRoom = UInt8(truncatingIfNeeded: newRoom)
    pendingRoomAction = 5
    commitMove(newRoom, locationAppearance)
  }

  private func currentAppearance() -> UInt8 {
    let index = Int(currentLocationIndex)
    if locations.indices.contains(index) {
      return locations[index].appearance
    }
    return UInt8(truncatingIfNeeded: locationAndRoom >> 8)
  }

  private func placeKind(_ appearance: UInt8) -> DunePlaceKind {
    if appearance >= 0x30 { return .harkonnenPalace }
    if appearance >= 0x28 { return .fort }
    if appearance >= 0x21 { return .village }
    if appearance >= 0x20 { return .palace }
    return .sietch
  }

  private func sceneIndex(for code: UInt16) -> Int? {
    let place = Int(code >> 8)
    let room = Int(code & 0xFF)
    guard room > 0, place < sceneDispatch.count else { return nil }
    let index = Int(sceneDispatch[place]) + room - 1
    guard sceneRecords.indices.contains(index) else { return nil }
    return index
  }

  private func exitByte(_ direction: Int) -> UInt8? {
    guard let index = sceneIndex(for: locationAndRoom) else { return nil }
    let exits = sceneRecords[index].exits
    let values = [exits.0, exits.1, exits.2, exits.3]
    return values[direction - 1]
  }

  private func currentSalRoom() -> Int {
    guard let index = sceneIndex(for: locationAndRoom) else { return 0 }
    return Int((sceneRecords[index].background &- 1) & 0x0F)
  }

  private func compassDirections() -> UIDirection {
    guard let index = sceneIndex(for: locationAndRoom) else { return [] }
    let exits = sceneRecords[index].exits
    let values = [exits.0, exits.1, exits.2, exits.3]
    let arrows: [UIDirection] = [.up, .right, .down, .left]
    var shown = UIDirection()
    var i = 0
    while i < 4 {
      let exit = values[i]
      if exit != 0 && (exit & 0x80 == 0 || exit >= 0xFB) {
        shown.insert(arrows[i])
      }
      i += 1
    }
    return shown
  }

  private mutating func markVisitedIfNeeded() {
    let index = Int(currentLocationIndex)
    guard locations.indices.contains(index) else { return }
    var placed = locations
    if placed[index].status & 0x10 == 0 {
      placed[index].status |= 0x10
      if locationAndRoom >> 8 < 0x20 {
        numberOfSietchesVisited &+= 1
      }
      enteringNewSietech = 0xFF
    }
    locations = placed
  }

  private mutating func walkOut(_ exit: UInt8) {
    let stepIndex = Int(UInt8(truncatingIfNeeded: -Int(exit)))
    guard desertStepDeltas.indices.contains(stepIndex) else { return }
    let index = Int(currentLocationIndex)
    guard locations.indices.contains(index) else { return }

    paulFoundUnconscious = 0
    lastLocationIndex = index
    currentLocationIndex = 0xFFFF
    let location = locations[index]
    data_0008 = 0xFF
    data_0009 = 0xFF
    let longitude = UInt16(bitPattern: location.mapX)
    let latitude = UInt16(bitPattern: location.mapY) & 0xFF
    stepDesert(stepIndex, longitude, latitude)
  }

  private mutating func stepDesert(_ direction: Int, _ longitude: UInt16, _ latfine: UInt16) {
    guard desertStepDeltas.indices.contains(direction) else { return }
    let stepped = applyDesertStep(desertStepDeltas[direction], longitude, latfine)
    if stepped.latfine & 0xFF00 != 0 {
      commitMove(stepped.x, stepped.latfine)
      return
    }
    checkArrival(stepped.x, stepped.latfine)
  }

  private mutating func checkArrival(_ longitude: UInt16, _ latfine: UInt16) {
    let lat = Int16(Int8(bitPattern: UInt8(truncatingIfNeeded: latfine)))
    let offset = mapState.position(x: longitude, lat: lat).offset
    guard mapState.bytes.indices.contains(offset), mapState.bytes[offset] & 0x40 != 0 else {
      commitMove(longitude, latfine)
      return
    }
    guard let index = locations.firstIndex(where: { $0.mapOffset == UInt16(truncatingIfNeeded: offset) }) else {
      commitMove(longitude, latfine)
      return
    }
    if UInt16(bitPattern: locations[index].mapX) != longitude {
      commitMove(longitude, latfine)
      return
    }
    arrive(index)
  }

  private mutating func arrive(_ index: Int) {
    desertStepCounter = 0
    currentLocationIndex = UInt16(index)
    lastLocationIndex = index

    var placed = locations
    if placed[index].status & 0x80 != 0 {
      placed[index].status &= 0x7F
      if placed[index].appearance < 0x20 {
        numberOfSietchesDiscovered &+= 1
      }
    }
    let newRoom = (UInt16(placed[index].appearance) << 8) | 1
    if newRoom >> 8 >= 0x20 {
      placed[index].status |= 0x10
    }
    locations = placed

    let slot = (UInt16(index + 1) << 8) | 0x80
    commitMove(newRoom, slot)
  }

  private mutating func commitMove(_ newRoom: UInt16, _ newAppearance: UInt16) {
    previousRoom = currentRoom
    currentRoom = UInt8(truncatingIfNeeded: newRoom)
    locationAndRoom = newRoom
    locationAppearance = newAppearance
    if newAppearance & 0xFF == 0x80 {
      data_0008 = UInt8(truncatingIfNeeded: newRoom >> 8)
      data_0009 = UInt8(truncatingIfNeeded: newAppearance >> 8)
    } else {
      data_0008 = 0xFF
      data_0009 = 0xFF
    }
  }

  private func applyDesertStep(_ step: UInt16, _ longitude: UInt16, _ latfine: UInt16) -> (x: UInt16, latfine: UInt16) {
    let ah = UInt8(truncatingIfNeeded: step >> 8)
    var latitude = UInt8(truncatingIfNeeded: latfine)
    var fine = UInt8(truncatingIfNeeded: latfine >> 8)
    let signed = Int8(bitPattern: ah)
    if signed > 0 {
      let added = fine.addingReportingOverflow(ah)
      fine = added.partialValue
      if added.overflow {
        latitude = latitude &+ 1
        if Int8(bitPattern: latitude) >= 0x62 {
          latitude = latitude &- 1
          fine = fine &- ah
        }
      }
    } else if signed < 0 {
      let added = fine.addingReportingOverflow(ah)
      fine = added.partialValue
      if !added.overflow {
        latitude = latitude &- 1
        if Int8(bitPattern: latitude) <= -0x62 {
          latitude = latitude &+ 1
          fine = fine &- ah
        }
      }
    }
    let delta = UInt16(bitPattern: Int16(Int8(bitPattern: UInt8(truncatingIfNeeded: step))))
    let packed = (UInt16(fine) << 8) | UInt16(latitude)
    return (longitude &+ delta, packed)
  }
}
