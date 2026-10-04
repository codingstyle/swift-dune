//
//  Troop.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 13/09/2026.
//

// = seg001:08aa troops — one entry of the 68-troop table (27-byte stride).
// The troop list per location is a linked list chained via
// Location.troopId (head) -> DuneTroop.nextTroopId, both 1-based
// (0 = end of list), indexed as troops[id - 1].
struct DuneTroop {
  var troopId: UInt8 = 0
  var nextTroopId: UInt8 = 0
  var position: UInt8 = 0
  var occupation: UInt8 = 0
  var locationOffset: UInt16 = 0
  var gpsCoordinates1: UInt16 = 0
  var gpsCoordinates2: UInt16 = 0
  var timePeriodOfRalliement: UInt16 = 0
  // = troop +0x0c/+0x0e — the two accumulators the current occupation
  // writes, cleared whenever it changes (troop_set_occupation). For spice
  // mining they are this period's harvest rate and the running total
  // behind the info panel's "Current:" / "Average: N kgs/h". An attacking
  // troop keeps losses and kills here; an ecology troop its covered area.
  // A moving troop (occupation bit 6) keeps its home location ptr in +0x0c
  // and the equipment-to-fetch word in +0x0e.
  var harvestRate: UInt16 = 0
  var harvestTotal: UInt16 = 0
  var flags: UInt16 = 0
  var dissatisfactionAndSpeech: UInt16 = 0
  var gameDayOfRalliement: UInt8 = 0
  var motivation: UInt8 = 0
  var spiceSkill: UInt8 = 0
  var armySkill: UInt8 = 0
  var ecologySkill: UInt8 = 0
  // Held-equipment bitmask, bit 7 = harvesters .. bit 1 = bulbs.
  var equipment: UInt8 = 0
  var population: UInt8 = 0

  init() { }

  init(
    troopId: UInt8,
    nextTroopId: UInt8 = 0,
    position: UInt8,
    occupation: UInt8,
    flags: UInt16 = 0,
    dissatisfactionAndSpeech: UInt16 = 0,
    motivation: UInt8,
    spiceSkill: UInt8,
    armySkill: UInt8,
    ecologySkill: UInt8,
    equipment: UInt8 = 0,
    population: UInt8
  ) {
    self.troopId = troopId
    self.nextTroopId = nextTroopId
    self.position = position
    self.occupation = occupation
    self.flags = flags
    self.dissatisfactionAndSpeech = dissatisfactionAndSpeech
    self.motivation = motivation
    self.spiceSkill = spiceSkill
    self.armySkill = armySkill
    self.ecologySkill = ecologySkill
    self.equipment = equipment
    self.population = population
  }
}


extension DuneDataSegment where T == DuneTroop {
  init(_ offset: UInt16) {
    self.init(wrappedValue: DuneTroop(), offset)
  }
}


// = seg001:08aa troops — the 68-entry troop table's static initializer.
let initialTroops: [DuneTroop] = [
  // [0]
  DuneTroop(troopId: 1, position: 1, occupation: 0x80, dissatisfactionAndSpeech: 0x40, motivation: 28, spiceSkill: 10, armySkill: 10, ecologySkill: 0, population: 190),
  // [1]
  DuneTroop(troopId: 2, position: 1, occupation: 0x80, motivation: 26, spiceSkill: 20, armySkill: 60, ecologySkill: 0, population: 208),
  // [2]
  // Prospector troop: starts unhired at Carthag-Timin (locations[11],
  // visible from the start); its chief's phase-4 line rallies it, and
  // MOVE TROOP on it opens menu_map_move_prospectors.
  DuneTroop(troopId: 3, position: 1, occupation: 0x80, motivation: 16, spiceSkill: 14, armySkill: 0, ecologySkill: 0, population: 40),
  // [3]
  DuneTroop(troopId: 4, position: 1, occupation: 0x80, motivation: 40, spiceSkill: 12, armySkill: 10, ecologySkill: 22, population: 243),
  // [4]
  DuneTroop(troopId: 5, position: 1, occupation: 0x80, motivation: 30, spiceSkill: 14, armySkill: 10, ecologySkill: 26, population: 174),
  // [5]
  DuneTroop(troopId: 6, position: 1, occupation: 0x80, motivation: 26, spiceSkill: 20, armySkill: 10, ecologySkill: 30, population: 150),
  // [6]
  DuneTroop(troopId: 7, position: 1, occupation: 0x80, motivation: 22, spiceSkill: 0, armySkill: 10, ecologySkill: 20, population: 201),
  // [7]
  DuneTroop(troopId: 8, position: 1, occupation: 0x80, motivation: 31, spiceSkill: 11, armySkill: 22, ecologySkill: 24, population: 136),
  // [8]
  DuneTroop(troopId: 9, position: 1, occupation: 0x80, motivation: 25, spiceSkill: 4, armySkill: 11, ecologySkill: 26, population: 235),
  // [9]
  DuneTroop(troopId: 10, position: 1, occupation: 0x80, motivation: 23, spiceSkill: 12, armySkill: 17, ecologySkill: 17, population: 252),
  // [10]
  DuneTroop(troopId: 11, position: 1, occupation: 0x80, motivation: 19, spiceSkill: 12, armySkill: 31, ecologySkill: 8, population: 241),
  // [11]
  DuneTroop(troopId: 12, position: 1, occupation: 0x80, motivation: 12, spiceSkill: 5, armySkill: 1, ecologySkill: 29, population: 134),
  // [12]
  DuneTroop(troopId: 13, position: 1, occupation: 0x80, dissatisfactionAndSpeech: 0x40, motivation: 23, spiceSkill: 22, armySkill: 11, ecologySkill: 22, population: 213),
  // [13]
  DuneTroop(troopId: 14, position: 1, occupation: 0x80, dissatisfactionAndSpeech: 0x40, motivation: 21, spiceSkill: 12, armySkill: 29, ecologySkill: 22, population: 96),
  // [14]
  DuneTroop(troopId: 15, position: 1, occupation: 0x80, dissatisfactionAndSpeech: 0x40, motivation: 20, spiceSkill: 28, armySkill: 11, ecologySkill: 3, population: 235),
  // [15]
  DuneTroop(troopId: 16, position: 1, occupation: 0x80, motivation: 31, spiceSkill: 11, armySkill: 28, ecologySkill: 6, population: 123),
  // [16]
  DuneTroop(troopId: 17, position: 1, occupation: 0x80, motivation: 39, spiceSkill: 9, armySkill: 31, ecologySkill: 0, population: 107),
  // [17]
  DuneTroop(troopId: 18, position: 1, occupation: 0x80, motivation: 17, spiceSkill: 19, armySkill: 10, ecologySkill: 18, population: 214),
  // [18]
  DuneTroop(troopId: 19, position: 1, occupation: 0x80, dissatisfactionAndSpeech: 0x40, motivation: 23, spiceSkill: 12, armySkill: 29, ecologySkill: 3, population: 237),
  // [19]
  DuneTroop(troopId: 20, position: 1, occupation: 0x80, dissatisfactionAndSpeech: 0x40, motivation: 22, spiceSkill: 13, armySkill: 1, ecologySkill: 22, population: 66),
  // [20]
  DuneTroop(troopId: 21, position: 1, occupation: 0x80, motivation: 6, spiceSkill: 10, armySkill: 11, ecologySkill: 25, population: 172),
  // [21]
  DuneTroop(troopId: 22, position: 1, occupation: 0x80, motivation: 15, spiceSkill: 1, armySkill: 22, ecologySkill: 6, population: 236),
  // [22]
  DuneTroop(troopId: 23, position: 1, occupation: 0x80, motivation: 21, spiceSkill: 1, armySkill: 19, ecologySkill: 30, population: 76),
  // [23]
  DuneTroop(troopId: 24, position: 1, occupation: 0x80, motivation: 8, spiceSkill: 8, armySkill: 10, ecologySkill: 19, population: 155),
  // [24]
  DuneTroop(troopId: 25, position: 1, occupation: 0x80, motivation: 16, spiceSkill: 21, armySkill: 6, ecologySkill: 31, population: 222),
  // [25]
  DuneTroop(troopId: 26, position: 1, occupation: 0x80, motivation: 31, spiceSkill: 13, armySkill: 4, ecologySkill: 13, population: 148),
  // [26]
  DuneTroop(troopId: 27, nextTroopId: 28, position: 9, occupation: 0x8c, flags: 0x90, motivation: 80, spiceSkill: 30, armySkill: 80, ecologySkill: 6, equipment: 0x38, population: 180),
  // [27]
  DuneTroop(troopId: 28, nextTroopId: 29, position: 10, occupation: 0x8c, flags: 0x90, motivation: 80, spiceSkill: 30, armySkill: 80, ecologySkill: 23, equipment: 0x38, population: 180),
  // [28]
  DuneTroop(troopId: 29, position: 11, occupation: 0x8c, flags: 0x90, motivation: 80, spiceSkill: 30, armySkill: 80, ecologySkill: 11, equipment: 0x38, population: 180),
  // [29]
  DuneTroop(troopId: 30, nextTroopId: 31, position: 9, occupation: 0x8c, flags: 0x90, motivation: 70, spiceSkill: 30, armySkill: 80, ecologySkill: 5, equipment: 0x3c, population: 180),
  // [30]
  DuneTroop(troopId: 31, nextTroopId: 32, position: 10, occupation: 0x8c, flags: 0x90, motivation: 70, spiceSkill: 30, armySkill: 80, ecologySkill: 2, equipment: 0x38, population: 180),
  // [31]
  DuneTroop(troopId: 32, position: 11, occupation: 0x8c, flags: 0x90, motivation: 70, spiceSkill: 30, armySkill: 80, ecologySkill: 30, equipment: 0x3c, population: 180),
  // [32]
  DuneTroop(troopId: 33, nextTroopId: 34, position: 9, occupation: 0x8c, flags: 0x90, motivation: 80, spiceSkill: 30, armySkill: 80, ecologySkill: 24, equipment: 0x38, population: 180),
  // [33]
  DuneTroop(troopId: 34, nextTroopId: 35, position: 10, occupation: 0x8c, flags: 0x90, motivation: 60, spiceSkill: 30, armySkill: 80, ecologySkill: 28, equipment: 0x38, population: 180),
  // [34]
  DuneTroop(troopId: 35, position: 11, occupation: 0x8c, flags: 0x90, motivation: 80, spiceSkill: 30, armySkill: 80, ecologySkill: 15, equipment: 0x30, population: 180),
  // [35]
  DuneTroop(troopId: 36, nextTroopId: 37, position: 9, occupation: 0x8c, flags: 0x90, motivation: 40, spiceSkill: 30, armySkill: 80, ecologySkill: 0, equipment: 0x18, population: 182),
  // [36]
  DuneTroop(troopId: 37, nextTroopId: 38, position: 10, occupation: 0x8c, flags: 0x90, motivation: 40, spiceSkill: 30, armySkill: 80, ecologySkill: 2, equipment: 0x10, population: 182),
  // [37]
  DuneTroop(troopId: 38, position: 11, occupation: 0x8c, flags: 0x90, motivation: 40, spiceSkill: 30, armySkill: 80, ecologySkill: 15, equipment: 0x10, population: 182),
  // [38]
  DuneTroop(troopId: 39, nextTroopId: 40, position: 9, occupation: 0x8c, flags: 0x90, motivation: 60, spiceSkill: 30, armySkill: 80, ecologySkill: 30, equipment: 0x18, population: 185),
  // [39]
  DuneTroop(troopId: 40, position: 10, occupation: 0x8c, flags: 0x90, motivation: 50, spiceSkill: 30, armySkill: 80, ecologySkill: 29, equipment: 0x18, population: 190),
  // [40]
  DuneTroop(troopId: 41, nextTroopId: 42, position: 9, occupation: 0x8c, flags: 0x90, motivation: 70, spiceSkill: 30, armySkill: 80, ecologySkill: 10, equipment: 0x3c, population: 190),
  // [41]
  DuneTroop(troopId: 42, nextTroopId: 43, position: 10, occupation: 0x8c, flags: 0x90, motivation: 70, spiceSkill: 30, armySkill: 80, ecologySkill: 3, equipment: 0x38, population: 190),
  // [42]
  DuneTroop(troopId: 43, position: 11, occupation: 0x8c, flags: 0x90, motivation: 70, spiceSkill: 30, armySkill: 80, ecologySkill: 27, equipment: 0x3c, population: 190),
  // [43]
  DuneTroop(troopId: 44, nextTroopId: 45, position: 9, occupation: 0x8c, flags: 0x90, motivation: 80, spiceSkill: 30, armySkill: 80, ecologySkill: 27, equipment: 0x10, population: 185),
  // [44]
  DuneTroop(troopId: 45, nextTroopId: 46, position: 10, occupation: 0x8c, flags: 0x90, motivation: 80, spiceSkill: 30, armySkill: 80, ecologySkill: 19, equipment: 0x10, population: 185),
  // [45]
  DuneTroop(troopId: 46, position: 11, occupation: 0x8c, flags: 0x90, motivation: 80, spiceSkill: 30, armySkill: 80, ecologySkill: 24, equipment: 0x10, population: 185),
  // [46]
  DuneTroop(troopId: 47, nextTroopId: 48, position: 9, occupation: 0x8c, flags: 0x90, motivation: 10, spiceSkill: 30, armySkill: 70, ecologySkill: 18, equipment: 0x30, population: 188),
  // [47]
  DuneTroop(troopId: 48, nextTroopId: 49, position: 10, occupation: 0x8c, flags: 0x90, motivation: 17, spiceSkill: 30, armySkill: 69, ecologySkill: 15, equipment: 0x10, population: 188),
  // [48]
  DuneTroop(troopId: 49, position: 11, occupation: 0x8c, flags: 0x90, motivation: 20, spiceSkill: 30, armySkill: 65, ecologySkill: 31, equipment: 0x10, population: 188),
  // [49]
  DuneTroop(troopId: 50, nextTroopId: 51, position: 9, occupation: 0x8c, flags: 0x90, motivation: 25, spiceSkill: 30, armySkill: 48, ecologySkill: 7, equipment: 0x18, population: 188),
  // [50]
  DuneTroop(troopId: 51, position: 10, occupation: 0x8c, flags: 0x90, motivation: 25, spiceSkill: 30, armySkill: 58, ecologySkill: 22, equipment: 0x18, population: 188),
  // [51]
  DuneTroop(troopId: 52, position: 9, occupation: 0x8c, flags: 0x90, motivation: 70, spiceSkill: 30, armySkill: 80, ecologySkill: 4, equipment: 0x38, population: 185),
  // [52]
  DuneTroop(troopId: 53, position: 9, occupation: 0x8c, flags: 0x90, motivation: 90, spiceSkill: 30, armySkill: 90, ecologySkill: 9, equipment: 0x1c, population: 180),
  // [53]
  DuneTroop(troopId: 54, position: 9, occupation: 0x8c, flags: 0x90, motivation: 40, spiceSkill: 30, armySkill: 80, ecologySkill: 13, equipment: 0x18, population: 180),
  // [54]
  DuneTroop(troopId: 55, nextTroopId: 56, position: 9, occupation: 0x8c, flags: 0x90, motivation: 12, spiceSkill: 30, armySkill: 34, ecologySkill: 2, equipment: 0x30, population: 180),
  // [55]
  DuneTroop(troopId: 56, position: 10, occupation: 0x8c, flags: 0x90, motivation: 12, spiceSkill: 30, armySkill: 34, ecologySkill: 23, equipment: 0x30, population: 180),
  // [56]
  DuneTroop(troopId: 57, position: 9, occupation: 0x8c, flags: 0x90, motivation: 10, spiceSkill: 30, armySkill: 34, ecologySkill: 0, equipment: 0x30, population: 180),
  // [57]
  DuneTroop(troopId: 58, position: 9, occupation: 0x8c, flags: 0x90, motivation: 10, spiceSkill: 30, armySkill: 16, ecologySkill: 31, equipment: 0x30, population: 180),
  // [58]
  DuneTroop(troopId: 59, position: 9, occupation: 0x8c, flags: 0x90, motivation: 10, spiceSkill: 30, armySkill: 10, ecologySkill: 16, equipment: 0x30, population: 180),
  // [59]
  DuneTroop(troopId: 60, position: 9, occupation: 0x8c, flags: 0x90, motivation: 80, spiceSkill: 30, armySkill: 80, ecologySkill: 15, equipment: 0x10, population: 180),
  // [60]
  DuneTroop(troopId: 61, position: 9, occupation: 0x8c, flags: 0x90, motivation: 99, spiceSkill: 30, armySkill: 80, ecologySkill: 21, equipment: 0x3c, population: 180),
  // [61]
  DuneTroop(troopId: 62, position: 9, occupation: 0x8c, flags: 0x90, motivation: 60, spiceSkill: 30, armySkill: 80, ecologySkill: 22, equipment: 0x18, population: 180),
  // [62]
  DuneTroop(troopId: 63, nextTroopId: 64, position: 9, occupation: 0x8c, flags: 0x90, motivation: 70, spiceSkill: 30, armySkill: 80, ecologySkill: 16, equipment: 0x38, population: 180),
  // [63]
  DuneTroop(troopId: 64, nextTroopId: 65, position: 10, occupation: 0x8c, flags: 0x90, motivation: 70, spiceSkill: 30, armySkill: 80, ecologySkill: 30, equipment: 0x08, population: 180),
  // [64]
  DuneTroop(troopId: 65, position: 11, occupation: 0x8c, flags: 0x90, motivation: 70, spiceSkill: 30, armySkill: 80, ecologySkill: 22, equipment: 0x30, population: 180),
  // [65]
  DuneTroop(troopId: 66, position: 9, occupation: 0x8c, flags: 0x90, motivation: 50, spiceSkill: 30, armySkill: 80, ecologySkill: 20, equipment: 0x18, population: 180),
  // [66]
  DuneTroop(troopId: 67, position: 9, occupation: 0x8c, flags: 0x90, motivation: 8, spiceSkill: 30, armySkill: 95, ecologySkill: 20, equipment: 0x38, population: 10),
  // [67] empty slot (troop_id 0)
  DuneTroop(troopId: 0, position: 0, occupation: 0, motivation: 0, spiceSkill: 0, armySkill: 0, ecologySkill: 0, population: 0)
]
