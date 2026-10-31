//
//  Menus.swift
//  SwiftDune
//
//  The command-strip scenarios from seg001 (menu_defs). UI paints the
//  active scenario; a click either turns the " Others..." page or
//  reports the chosen record.
//

import Foundation

enum MenuScenario: Int {
  case command
  case npcActions
  case goTowardsThisPlace
  case destinationWarning
  case continueOrWhat
  case continueSequence
  case dynamic
  case commsRoomMessagesViewed
  case argueAcceptRefuse
  case done
  case mixerPanel
  case book
  case globe
  case globeDefaultClick
  case music
  case saveGame
  case loadGame
  case restartLoadExitGame
  case exitGameConfirmation
  case palaceMirrorRoom
  case goThereFlyingAnOrni
  case goThereRidingAWorm
  case mapTroops
  case troopDialog
  case nextTroop
  case cancel
  case moveProspectors
  case changeTroopDestination
  case selectTroopOccupation
  case occupationForSpiceTroop
  case occupationForArmyTroop
  case occupationForEspionageTroop
  case occupationForEcologyTroop
}

enum MenuHandler {
  static let exitMenu: UInt16 = 0xd2e2
  static let closeBook: UInt16 = 0xb18b
  static let exitGlobe: UInt16 = 0xbc81
  static let exitMaps: UInt16 = 0x186b
  // Non-zero so Menus.choose delivers the click. Original offset is not mapped yet.
  static let seeDuneMap: UInt16 = 0x0001
  static let lookAtMirror: UInt16 = 0x0ea6
  static let lookAwayFromTheMirror: UInt16 = 0x0eb9
  static let seeResults: UInt16 = 0xb96b
  static let seeStandardVision: UInt16 = 0xb961
}

/// Floppy COMMAND.HSQ indexes. The PC-CD table inserts strings, so the same
/// label sits at a higher index there.
enum CommandId {
  static let askForMoreInformation: UInt16 = 0x42
  static let modifyEquipment: UInt16 = 0x43
  static let changeTroopOccupation: UInt16 = 0x44
  static let moveTroop: UInt16 = 0x45
  static let nextTroop: UInt16 = 0x46
  static let noMoreOrders: UInt16 = 0x47
  static let changeDestination: UInt16 = 0x4d
  static let goThereFlyingAnOrni: UInt16 = 0x4e
  static let goThereRidingAWorm: UInt16 = 0x4f
  static let addADestination: UInt16 = 0x50
  static let giveNewDestinations: UInt16 = 0x51
  static let goSearchForEquipment: UInt16 = 0x52
  static let espionage: UInt16 = 0x54
  static let attack: UInt16 = 0x55
  static let assemblyWindTrap: UInt16 = 0x56
  static let contactFremenTroops: UInt16 = 0x57
  static let exitMaps: UInt16 = 0x58
  static let seeSpiceDensity: UInt16 = 0x59
  static let findProspectors: UInt16 = 0x5c
  static let specializeInSpice: UInt16 = 0x6a
  static let specializeInArmy: UInt16 = 0x6b
  static let specializeInEcology: UInt16 = 0x6c
  static let talkToMe: UInt16 = 0x85
  static let comeWithMe: UInt16 = 0x86
  static let stayHere: UInt16 = 0x87
  static let giveOrdersToTroop: UInt16 = 0x88
  static let stopTalking: UInt16 = 0x89
  static let seeDuneMap: UInt16 = 0x8d
  static let lookAtMirror: UInt16 = 0x8e
  static let lookAwayFromTheMirror: UInt16 = 0x92
  static let others: UInt16 = 0x93
  static let done: UInt16 = 0x94
  static let continueVerb: UInt16 = 0x95
  static let cancel: UInt16 = 0x96
  static let takeAnOrnithopter: UInt16 = 0x9a
  static let goTowardsThisPlace: UInt16 = 0xa0
  static let ignoreWarning: UInt16 = 0xa1
  static let seeResults: UInt16 = 0xa4
  static let standardVision: UInt16 = 0xa5
  static let saveGame: UInt16 = 0xa6
  static let loadGame: UInt16 = 0xa7
  static let optionsAndQuit: UInt16 = 0xa8
  static let seeMapOfThisArea: UInt16 = 0xa9
  static let exitGlobe: UInt16 = 0xaa
  static let yesIWantToExitGame: UInt16 = 0xab
  static let noIDontWantToFinish: UInt16 = 0xac
  static let restartGame: UInt16 = 0xad
  static let exitGame: UInt16 = 0xae
  static let viewed: UInt16 = 0xcc
  static let allTopics: UInt16 = 0xd6
  static let topicPolitics: UInt16 = 0xd7
  static let topicPaulOnDune: UInt16 = 0xd8
  static let topicSpice: UInt16 = 0xd9
  static let topicTheFremen: UInt16 = 0xda
  static let accept: UInt16 = 0xe2
  static let refuse: UInt16 = 0xe3
  static let argue: UInt16 = 0xe4
  static let musicOnCdStyle: UInt16 = 0xfd
  static let musicOnGameRelative: UInt16 = 0xfe
  static let shuffle: UInt16 = 0xff
  static let standardOrder: UInt16 = 0x100
  static let musicOff: UInt16 = 0x101
  static let log1: UInt16 = 0x102
  static let log2: UInt16 = 0x103
  static let lastEnteringIntoAPlace: UInt16 = 0x104
  static let lastEnteringNewSietch: UInt16 = 0x105
}

struct MenuRecord {
  var textId: UInt16
  var handler: UInt16
  var greyed: Bool = false
  var highlighted: Bool = false
}

struct MenuRow {
  var textId: UInt16
  var greyed: Bool
  var highlighted: Bool
}

struct MenuChoice {
  var scenario: MenuScenario
  var textId: UInt16
  var handler: UInt16
  var slot: Int
}

final class Menus {
  @MainActor static let shared = Menus()

  private(set) var scenario: MenuScenario = .command
  private var stack: [MenuScenario] = []
  private var records: [MenuScenario: [MenuRecord]] = [:]
  private var skip: [MenuScenario: Int] = [:]

  private init() {
    var seeded: [MenuScenario: [MenuRecord]] = [:]
    for (scenario, template) in Menus.templates {
      seeded[scenario] = template
    }
    records = seeded
  }

  func show(_ scenario: MenuScenario) {
    stack.removeAll()
    self.scenario = scenario
    skip[scenario] = 0
  }

  func push(_ scenario: MenuScenario) {
    stack.append(self.scenario)
    self.scenario = scenario
    skip[scenario] = 0
  }

  func pop() {
    scenario = stack.popLast() ?? .command
  }

  func setRecords(_ scenario: MenuScenario, _ records: [MenuRecord]) {
    self.records[scenario] = records
    skip[scenario] = 0
  }

  func visibleRows() -> [MenuRow] {
    layout().rows
  }

  func choose(slot: Int) -> MenuChoice? {
    let laid = layout()
    guard slot >= 0, slot < laid.slotCount else { return nil }
    if laid.moreSlot == slot {
      if laid.moreAhead {
        skip[scenario] = (skip[scenario] ?? 0) + 4
      } else {
        skip[scenario] = 0
      }
      return nil
    }
    let index = (skip[scenario] ?? 0) + slot
    let buffer = records[scenario] ?? []
    guard buffer.indices.contains(index) else { return nil }
    let record = buffer[index]
    if record.greyed || record.textId == 0 || record.handler == 0 {
      return nil
    }
    return MenuChoice(scenario: scenario, textId: record.textId, handler: record.handler, slot: slot)
  }

  private struct Layout {
    var rows: [MenuRow]
    var slotCount: Int
    var moreSlot: Int?
    var moreAhead: Bool
  }

  private func layout() -> Layout {
    let buffer = records[scenario] ?? []
    let start = skip[scenario] ?? 0
    var rows: [MenuRow] = []
    rows.reserveCapacity(5)
    var index = start
    var slot = 0
    var moreSlot: Int?
    var moreAhead = false
    let scrolled = start > 0

    while slot < 5 {
      if index >= buffer.count || buffer[index].textId == 0 {
        if scrolled {
          rows.append(MenuRow(textId: CommandId.others, greyed: false, highlighted: false))
          moreSlot = slot
          slot += 1
        }
        while slot < 5 {
          rows.append(MenuRow(textId: 0, greyed: false, highlighted: false))
          slot += 1
        }
        break
      }

      if slot == 4 && (scrolled || index + 1 < buffer.count) {
        moreAhead = true
        moreSlot = slot
        rows.append(MenuRow(textId: CommandId.others, greyed: false, highlighted: false))
      } else {
        let record = buffer[index]
        rows.append(MenuRow(textId: record.textId, greyed: record.greyed, highlighted: record.highlighted))
      }
      index += 1
      slot += 1
    }

    var slotCount = 0
    while slotCount < rows.count && rows[slotCount].textId != 0 {
      slotCount += 1
    }
    return Layout(rows: rows, slotCount: slotCount, moreSlot: moreSlot, moreAhead: moreAhead)
  }

  private static func item(_ textId: UInt16, _ handler: UInt16) -> MenuRecord {
    MenuRecord(textId: textId, handler: handler)
  }

  private static func grey(_ textId: UInt16, _ handler: UInt16) -> MenuRecord {
    MenuRecord(textId: textId, handler: handler, greyed: true)
  }

  private static func highlight(_ textId: UInt16, _ handler: UInt16) -> MenuRecord {
    MenuRecord(textId: textId, handler: handler, highlighted: true)
  }

  private static let templates: [MenuScenario: [MenuRecord]] = [
    .command: [],
    .npcActions: [
      item(CommandId.talkToMe, 0x9472),
      item(CommandId.comeWithMe, 0x95e2),
      item(CommandId.stopTalking, MenuHandler.exitMenu)
    ],
    .goTowardsThisPlace: [
      item(CommandId.goTowardsThisPlace, MenuHandler.exitMenu)
    ],
    .destinationWarning: [
      item(CommandId.changeDestination, 0x497a),
      item(CommandId.ignoreWarning, MenuHandler.exitMenu)
    ],
    .continueOrWhat: [
      item(CommandId.continueVerb, 0x1707)
    ],
    .continueSequence: [
      item(CommandId.continueVerb, 0x1707)
    ],
    .dynamic: [
      item(0, 0),
      item(0, 0),
      item(0, 0)
    ],
    .commsRoomMessagesViewed: [
      item(CommandId.viewed, 0x2993)
    ],
    .argueAcceptRefuse: [
      item(CommandId.argue, 0x2453),
      item(CommandId.accept, 0x241a),
      item(CommandId.refuse, 0x2432)
    ],
    .done: [
      item(CommandId.done, MenuHandler.exitMenu)
    ],
    .mixerPanel: [
      item(CommandId.musicOff, 0xaeaf),
      item(CommandId.musicOnGameRelative, 0xac6e),
      item(CommandId.musicOnCdStyle, 0xac7e),
      item(CommandId.exitGame, 0x0e3e),
      item(CommandId.done, MenuHandler.exitMenu)
    ],
    .book: [
      item(CommandId.allTopics, 0xaf58),
      item(CommandId.topicPolitics, 0xaf60),
      item(CommandId.topicPaulOnDune, 0xaf60),
      item(CommandId.topicSpice, 0xaf68),
      item(CommandId.topicTheFremen, 0xaf70)
    ],
    .globe: [
      item(CommandId.exitGlobe, MenuHandler.exitGlobe),
      item(CommandId.seeResults, MenuHandler.seeResults),
      item(CommandId.saveGame, 0xb28c),
      item(CommandId.loadGame, 0xb29e),
      item(CommandId.optionsAndQuit, 0x0e3e)
    ],
    .globeDefaultClick: [
      highlight(CommandId.seeMapOfThisArea, 0x0f66)
    ],
    .music: [
      item(CommandId.standardOrder, 0xac97),
      item(CommandId.shuffle, 0xac90),
      item(CommandId.cancel, 0xd2df)
    ],
    .saveGame: [
      item(CommandId.log1, 0xb35a),
      item(CommandId.log2, 0xb35a),
      item(CommandId.cancel, MenuHandler.exitMenu)
    ],
    .loadGame: [
      item(CommandId.log1, 0xb3b0),
      item(CommandId.log2, 0xb3b0),
      item(CommandId.lastEnteringIntoAPlace, 0xb3b0),
      item(CommandId.lastEnteringNewSietch, 0xb3b0),
      item(CommandId.cancel, MenuHandler.exitMenu)
    ],
    .restartLoadExitGame: [
      item(CommandId.restartGame, 0x0e47),
      item(CommandId.loadGame, 0xb29e),
      item(CommandId.exitGame, 0x0e3e)
    ],
    .exitGameConfirmation: [
      item(CommandId.yesIWantToExitGame, 0x003a),
      item(CommandId.noIDontWantToFinish, MenuHandler.exitMenu)
    ],
    .palaceMirrorRoom: [
      item(CommandId.restartGame, 0x0e47),
      item(CommandId.loadGame, 0xb29e),
      item(CommandId.saveGame, 0xb28c),
      item(CommandId.exitGame, 0x0e3e),
      item(CommandId.lookAwayFromTheMirror, 0x0eb9)
    ],
    .goThereFlyingAnOrni: [
      item(CommandId.goThereFlyingAnOrni, 0x50db),
      item(CommandId.cancel, MenuHandler.exitMenu)
    ],
    .goThereRidingAWorm: [
      item(CommandId.goThereRidingAWorm, 0x50ea),
      item(CommandId.cancel, MenuHandler.exitMenu)
    ],
    .mapTroops: [
      item(CommandId.exitMaps, MenuHandler.exitMaps),
      item(CommandId.contactFremenTroops, 0x86cc),
      item(CommandId.seeSpiceDensity, 0x53f1),
      item(CommandId.takeAnOrnithopter, 0x42d9),
      item(CommandId.findProspectors, 0x5b1e)
    ],
    .troopDialog: [
      item(CommandId.askForMoreInformation, 0x7bed),
      item(CommandId.changeTroopOccupation, 0x69b3),
      item(CommandId.modifyEquipment, 0x7cbb),
      item(CommandId.moveTroop, 0x8064),
      item(CommandId.noMoreOrders, 0x8763)
    ],
    .nextTroop: [
      item(CommandId.nextTroop, 0x86fa),
      item(CommandId.noMoreOrders, 0x8770)
    ],
    .cancel: [
      item(CommandId.cancel, MenuHandler.exitMenu)
    ],
    .moveProspectors: [
      item(CommandId.addADestination, 0x80c7),
      item(CommandId.giveNewDestinations, 0x80d9),
      item(CommandId.done, 0x8214),
      item(CommandId.cancel, MenuHandler.exitMenu)
    ],
    .changeTroopDestination: [
      item(CommandId.changeDestination, 0x8064),
      item(CommandId.nextTroop, 0x86fa),
      item(CommandId.cancel, MenuHandler.exitMenu)
    ],
    .selectTroopOccupation: [
      item(CommandId.specializeInSpice, 0x6a71),
      item(CommandId.specializeInArmy, 0x6a83),
      grey(CommandId.specializeInEcology, 0x6a87),
      item(CommandId.cancel, MenuHandler.exitMenu)
    ],
    .occupationForSpiceTroop: [
      item(CommandId.goSearchForEquipment, 0x776d),
      item(CommandId.specializeInArmy, 0x6a83),
      item(CommandId.specializeInEcology, 0x6a87),
      item(CommandId.cancel, MenuHandler.exitMenu)
    ],
    .occupationForArmyTroop: [
      item(CommandId.goSearchForEquipment, 0x7734),
      grey(CommandId.espionage, 0x6a45),
      item(CommandId.specializeInSpice, 0x6a71),
      item(CommandId.specializeInEcology, 0x6a87),
      item(CommandId.cancel, MenuHandler.exitMenu)
    ],
    .occupationForEspionageTroop: [
      item(CommandId.attack, 0x6a2f),
      item(CommandId.cancel, MenuHandler.exitMenu)
    ],
    .occupationForEcologyTroop: [
      item(CommandId.goSearchForEquipment, 0x775c),
      item(CommandId.assemblyWindTrap, 0x6a2b),
      item(CommandId.specializeInSpice, 0x6a71),
      item(CommandId.specializeInArmy, 0x6a83),
      item(CommandId.cancel, MenuHandler.exitMenu)
    ]
  ]
}

struct MenuChoiceEventData {
  var choice: MenuChoice
}

extension EventManager {
  static let menuChoiceEvent = DuneEvent<MenuChoiceEventData>()
}
