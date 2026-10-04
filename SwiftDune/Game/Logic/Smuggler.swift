//
//  Smugglers.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 13/09/2026.
//


struct DuneSmuggler {
  var region: UInt8 = 0
  var willingnessToHaggle: UInt8 = 0
  /// +2 — state flags; bit 3 arms the daily restock (seg000:1cae).
  var field2: UInt8 = 0
  var field3: UInt8 = 0
  /// +4..+8 — the five stock counts: harvesters, ornithopters, krys
  /// knives, laser guns, weirding modules.
  var stock: [UInt8] = .init(repeating: 0, count: 5)
  /// +9..+0xd — the matching prices; bit 7 marks a slot the daily restock
  /// may refill.
  var prices: [UInt8] = .init(repeating: 0, count: 5)
  /// +0xe — the open bill (spice owed to this smuggler); 0 = none.
  var billValue: UInt16 = 0
  /// +0x10 — the in-game day the bill was raised (get_ingame_day).
  var billDay: UInt8 = 0
  
  init() { }
  
  init(_ region: UInt8, _ willingnessToHaggle: UInt8, _ stock: [UInt8], _ prices: [UInt8]) {
    self.region = region
    self.willingnessToHaggle = willingnessToHaggle
    self.stock = stock
    self.prices = prices
  }
}

extension DuneDataSegment where T == DuneSmuggler {
  init(_ offset: UInt16) {
    self.init(wrappedValue: DuneSmuggler(), offset)
  }
}

let initialSmugglers: [DuneSmuggler] = [
  DuneSmuggler(0x01, 0x00, [1, 2, 0, 2, 2], [0x9e, 0xcb, 0x0a, 0xa8, 0xfd]),
  DuneSmuggler(0x03, 0x01, [1, 2, 0, 2, 1], [0x9e, 0xcb, 0x0a, 0xa8, 0xe4]),
  DuneSmuggler(0x05, 0x03, [1, 1, 0, 0, 1], [0xb2, 0xe3, 0x0a, 0x28, 0xe4]),
  DuneSmuggler(0x06, 0x02, [0, 2, 3, 2, 2], [0x28, 0xd0, 0x8f, 0xb2, 0xfd]),
  DuneSmuggler(0x09, 0x03, [2, 1, 0, 0, 1], [0xb2, 0xd0, 0x0a, 0x28, 0xee]),
  DuneSmuggler(0x0b, 0x06, [1, 1, 2, 1, 0], [0xbc, 0xda, 0x8a, 0xa8, 0x64]),
];
