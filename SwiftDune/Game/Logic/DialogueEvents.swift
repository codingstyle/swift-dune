//
//  DialogueEvents.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 20/09/2026.
//

enum DialogueEvent: UInt8 {
  case none = 0x00
  case followMe = 0x01
  case stayHere = 0x02
  case triggerCutscene = 0x03
  case acceptRefuseArgueDuncan = 0x04
  case acceptRefuseArgueSmuggler = 0x05
  case endDialogue = 0x06
  case showEquipmentInMap = 0x07
  case speakerDependent1 = 0x08
  case speakerDependent2 = 0x09
  case holdUpSign = 0x0A
  case increaseGamePhaseBy1 = 0x0B
  case increaseGamePhaseBy4 = 0x0C
  case showLocationOnMap = 0x0D
  case increaseFinalAttackStage = 0x0E
  case speakerDependent3 = 0x0F
}


enum DialogueCutscene: UInt8 {
  case prospectorIntro
  case phase14
  case phase18
  case phase30
}


enum DialogueSpeakerId {
  static let jessica: UInt8 = 0x01
  static let duncan: UInt8 = 0x03
  static let stilgar: UInt8 = 0x05
  static let harkonnenCaptain: UInt8 = 0x0C
  static let smugglers: UInt8 = 0x0D
}


private let smugglerTableOffset: UInt16 = 0x10D8
private let smugglerRecordSize: UInt16 = 0x11


extension GameState {
  var ingameDay: UInt8 {
    return UInt8(truncatingIfNeeded: gameTime >> 4)
  }
  
  mutating func dispatchDialogueLineEvent(_ eventId: UInt8, flagsLo: UInt8) {
    guard let event = DialogueEvent(rawValue: eventId) else {
      return
    }
    dispatchDialogueLineEvent(event, flagsLo: flagsLo)
  }
  
  mutating func dispatchDialogueLineEvent(_ event: DialogueEvent, flagsLo: UInt8) {
    switch event {
      case .none:
        break
      case .followMe:
        dialogueInterruptGate = 0xFF
      case .stayHere:
        dialogueInterruptGate = 0
      case .triggerCutscene:
        startPhaseCutscene()
      case .acceptRefuseArgueDuncan:
        beginAcceptRefuseArgue(withSmuggler: false)
      case .acceptRefuseArgueSmuggler:
        beginAcceptRefuseArgue(withSmuggler: true)
      case .endDialogue:
        requestDialogueEnd()
      case .showEquipmentInMap:
        dialogueInterruptGate = 0x80
      case .speakerDependent1:
        dialogueEvent08SpeakerDependent()
      case .speakerDependent2:
        dialogueEvent09SpeakerDependent()
      case .holdUpSign:
        armHeadSign()
      case .increaseGamePhaseBy1:
        increaseGamePhaseBy1(flagsLo: flagsLo)
      case .increaseGamePhaseBy4:
        increaseGamePhaseBy4(flagsLo: flagsLo)
      case .showLocationOnMap:
        showStagedLocationOnMap()
      case .increaseFinalAttackStage:
        increaseFinalAttackStage(flagsLo: flagsLo)
      case .speakerDependent3:
        dialogueEvent0FSpeakerDependent()
    }
  }
  
  mutating func requestDialogueEnd() {
    dialogueEndRequest = dialogueEndRequest &+ 1
  }
  
  mutating func armHeadSign() {
    headSignArmed = true
  }
  
  mutating func runPostVoiceHooks() {
    if stilgarWaterOfLifePending {
      stilgarWaterOfLifePending = false
      dialogueEvent08StilgarDrinkWaterOfLife()
    }
  }
  
  mutating func fireDialogueLineEvent(_ sentence: inout DialogueSentence) -> UInt16 {
    let eventId = sentence.event
    if eventId != 0 {
      dispatchDialogueLineEvent(eventId, flagsLo: sentence.flagsLo)
    }
    
    if sentence.isReplayable && !sentence.isSpoken {
      let packed = UInt16((Int(sentence.fileOffset) - 2) >> 2) | (UInt16(currentSpeakerId) << 11)
      dialoguePlayedLog.append(packed)
    }
    
    lineSpokenThisConversation = 0xFF
    sentence.markSpoken()
    
    if dialogueEndRequest != 0 {
      dialogueEndRequest = 0
      return 0xFFFF
    }
    return UInt16(truncatingIfNeeded: sentence.fileOffset &+ 4)
  }
  
  
  private mutating func beginAcceptRefuseArgue(withSmuggler: Bool) {
    argueMenuWithSmuggler = withSmuggler ? 1 : 0
    smugglerArgueChoice = 0
    armHeadSign()
  }
  
  private mutating func startPhaseCutscene() {
    if gamePhase < 0x14 {
      pendingCutscene = .prospectorIntro
    } else if gamePhase < 0x18 {
      pendingCutscene = .phase14
    } else if gamePhase < 0x30 {
      pendingCutscene = .phase18
    } else {
      pendingCutscene = .phase30
    }
  }
  
  private mutating func increaseGamePhaseBy1(flagsLo: UInt8) {
    if (flagsLo & 0x80) != 0 {
      return
    }
    gamePhase = gamePhase &+ 1
    daysSinceLastGamePhaseChange = 0
    runGamePhaseTriggers()
    if gamePhase == 1 {
      makeDuncanIdahoVisible()
    }
  }
  
  private mutating func increaseGamePhaseBy4(flagsLo: UInt8) {
    if (flagsLo & 0x80) != 0 {
      return
    }
    let phase = (gamePhase & 0xFC) &+ 4
    setGamePhaseAndTriggerCallbacks(phase)
  }
  
  private mutating func increaseFinalAttackStage(flagsLo: UInt8) {
    if (flagsLo & 0x80) != 0 {
      return
    }
    finalAttackStage = finalAttackStage &+ 1
  }
  
  mutating func setGamePhaseAndTriggerCallbacks(_ phase: UInt8) {
    gamePhase = phase
    daysSinceLastGamePhaseChange = 0
    runGamePhaseTriggers()
  }
  
  mutating func runGamePhaseTriggers() {
    let saved = bookFlags
    bookFlags = saved | 0x80
    bookFlags = saved
  }
  
  mutating func makeDuncanIdahoVisible() {
    if roomPersons.count > 3 {
      roomPersons[3].locationAppearance = 0x0180
    }
  }
  
  mutating func increaseCharisma(_ amount: UInt8) {
    charisma = charisma &+ amount
  }
  
  mutating func spiceSpend(_ amount: UInt16) {
    spiceInStock = spiceInStock &- amount
    spiceSpentToday = spiceSpentToday &+ amount
  }
  
  
  private mutating func showStagedLocationOnMap() {
    if currentSpeakerId >= 0x0E {
      showLocationOnMapRequested = true
    }
    if voiceSubtitleMode == 1 {
      return
    }
    if stagedNameLocation == currentLocationIndex {
      return
    }
    showLocationOnMapRequested = true
  }
  
  
  private mutating func dialogueEvent08SpeakerDependent() {
    switch currentSpeakerId {
      case DialogueSpeakerId.jessica:
        dialogueEvent08Jessica()
      case DialogueSpeakerId.duncan:
        dialogueEvent08DuncanIdaho()
      case DialogueSpeakerId.stilgar:
        stilgarWaterOfLifePending = true
      case DialogueSpeakerId.harkonnenCaptain:
        let li = Int(conditStagedLocation)
        if li >= 0 && li < locations.count {
          locations[li].status &= 0x7F
        }
      case DialogueSpeakerId.smugglers:
        dialogueEvent08Smugglers()
      default:
        break
    }
  }
  
  private mutating func dialogueEvent08Jessica() {
    var range: UInt16
    if (paulFlags & 0x02) != 0 {
      increaseCharisma(0x28)
      range = 0xFFCE
    } else {
      range = locationVisibilityDistance
      if range == 1 {
        increaseCharisma(0x0A)
        range = 0x0A
      }
    }
    range = range &+ 0x14
    locationVisibilityDistance = range
    
    var contact: UInt8 = 0
    if range < 0x64 {
      contact = 0x80 &- UInt8(truncatingIfNeeded: range / 6)
    }
    contactDistanceRelated = contact
  }
  
  private mutating func dialogueEvent08StilgarDrinkWaterOfLife() {
    paulFlags |= 0x08
    if smugglerArgueChoice != 1 {
      return
    }
    if charisma < 0x64 {
      pendingRoomScreenRequest = 3
      return
    }
    paulFlags |= 0x02
    contactDistanceRelated = 0xFF
    pendingRoomAction = 0x11
  }
  
  mutating func dialogueEvent08DuncanIdaho() {
    smugglerArgueChoice = 0
    currentSmugglerBillAmount = 0
    relateToArguing_001a = 0
    
    let spice = spiceInStock
    if spice != 0 {
      smugglerArgueChoice = 3
    }
    stageSpiceArgueAmountsWithDuncan(spice)
    
    let day = ingameDay
    var bestAge: UInt8 = 0
    var best: Int? = nil
    var i = 0
    while i < smugglers.count {
      let smuggler = smugglers[i]
      if smuggler.billValue != 0 && (smuggler.field2 & 0x60) == 0 {
        let age = day &- smuggler.billDay
        if age > bestAge {
          bestAge = age
          best = i
        }
      }
      i += 1
    }
    
    let index: Int
    if let found = best {
      index = found
    } else {
      let start = smugglerIndex(from: currentSmugglerPtr) ?? 0
      var cursor = start
      var foundBill: Int?
      repeat {
        cursor += 1
        if cursor >= smugglers.count {
          cursor = 0
        }
        if smugglers[cursor].billValue != 0 {
          foundBill = cursor
          break
        }
      } while cursor != start
      
      guard let next = foundBill else {
        return
      }
      currentSmugglerPtr = smugglerPointer(next)
      index = next
    }
    
    stageSmugglerForCondit(index)
    stringSubstIds[6] = UInt16(smugglers[index].region)
  }
  
  mutating func stageSpiceArgueAmountsWithDuncan(_ stock: UInt16) {
    spiceShipmentFlags &= 0xF9
    let demand = spiceShipmentDemand
    let oneAndHalf = (demand >> 1) &+ demand
    let double = demand &+ demand
    let half = stock >> 1
    let threeQuarters = (stock >> 2) &+ half
    
    if stock < demand {
      spiceShipmentArgumentAmounts = [stock, threeQuarters, half, threeQuarters &- half]
    } else if stock < oneAndHalf {
      spiceShipmentFlags |= 2
      spiceShipmentArgumentAmounts = [demand, stock, threeQuarters, half]
    } else if stock < double {
      spiceShipmentFlags |= 4
      spiceShipmentArgumentAmounts = [demand, stock, threeQuarters, oneAndHalf]
    } else {
      spiceShipmentFlags |= 6
      spiceShipmentArgumentAmounts = [demand, stock, oneAndHalf, double]
    }
  }
  
  mutating func stageSmugglerForCondit(_ index: Int) {
    if index < 0 || index >= smugglers.count {
      return
    }
    let smuggler = smugglers[index]
    if roomPersons.count > 13 {
      roomPersons[13].fieldC = smugglerPointer(index)
    }
    relatedToPayingSmuggleBills_001c = smuggler.field2
    currentSmugglerBillAmount = smuggler.billValue
    relatedToPayingSmugglerBills_001f = 0
    if smuggler.billValue != 0 {
      relatedToPayingSmugglerBills_001f = ingameDay &- smuggler.billDay
    }
    currentSmugglerWillingnessToHaggle_001d = smuggler.willingnessToHaggle
  }
  
  mutating func dialogueEvent08Smugglers() {
    setGamePhaseAndTriggerCallbacks(0x3C)
    smugglerArgueCount = UInt8(truncatingIfNeeded: randomBits & 3)
    
    let day = ingameDay
    guard let index = smugglerIndex(from: roomPersons.count > 13 ? roomPersons[13].fieldC : 0) else {
      return
    }
    smugglers[index].field3 = day
    relateToArguing_001a = 0
    
    let modulus = wormEventLikelihoodByRegion[0]
    if modulus == 0 {
      return
    }
    
    var ax = stringSubstIds[3] &- 0xE8
    var wraps: UInt16 = 2
    
    while true {
      ax = ax &+ 1
      while true {
        let al = UInt8(truncatingIfNeeded: ax)
        if al < modulus {
          break
        }
        ax = (ax & 0xFF00) | UInt16(al &- modulus)
        wraps = wraps &- 1
        if wraps == 0 {
          return
        }
      }
      
      let slot = Int(ax)
      if slot >= 0 && slot < smugglers[index].stock.count && smugglers[index].stock[slot] != 0 {
        break
      }
    }
    
    stringSubstIds[3] = ax &+ 0xE8
    let price = smugglers[index].prices[Int(ax)]
    smugglerDialogueState = (price & 0x7F) << 1
  }
  
  
  private mutating func dialogueEvent09SpeakerDependent() {
    switch currentSpeakerId {
      case DialogueSpeakerId.duncan:
        dialogueEvent09DuncanIdaho()
      case DialogueSpeakerId.stilgar:
        break
      case DialogueSpeakerId.smugglers:
        break
      default:
        break
    }
  }
  
  mutating func dialogueEvent09DuncanIdaho() {
    let choice = smugglerArgueChoice
    let smuggler = smugglerIndex(from: roomPersons.count > 13 ? roomPersons[13].fieldC : 0)
    
    if choice == 2 {
      if argueMenuWithSmuggler != 0, let i = smuggler {
        smugglers[i].field2 = (smugglers[i].field2 & 0x9F) | 0x40
      }
      return
    }
    
    if choice >= 3 {
      if argueMenuWithSmuggler != 0, let i = smuggler {
        smugglers[i].field2 = (smugglers[i].field2 & 0x9F) | 0x20
      }
      return
    }
    
    if argueMenuWithSmuggler == 0 {
      let idx = Int((relateToArguing_001a &- 1) & 3)
      if idx >= 0 && idx < spiceShipmentArgumentAmounts.count {
        spiceShipmentState = spiceShipmentArgumentAmounts[idx]
      }
      shipmentReportSceneMask = 0xFFFF
    } else if let i = smuggler {
      let bill = smugglers[i].billValue
      smugglers[i].billValue = 0
      numberOfSmugglerBills = numberOfSmugglerBills &- 1
      spiceSpend(bill)
    }
  }
  
  
  private mutating func dialogueEvent0FSpeakerDependent() {
    switch currentSpeakerId {
      case DialogueSpeakerId.jessica:
        jessicaCommentedOnExhaustion = jessicaCommentedOnExhaustion &+ 1
      case DialogueSpeakerId.duncan:
        dialogueEvent0FDuncanIdaho()
      default:
        break
    }
  }
  
  private mutating func dialogueEvent0FDuncanIdaho() {
    if gamePhase < 0x10 {
      if roomPersons.count > 1 {
        roomPersons[1].flags.insert(.npcStoryBit)
      }
      return
    }
    
    requestDialogueEnd()
    spiceShipmentState = 0
    spiceShipmentFlags |= 1
    
    let location = shipmentFulfilmentClass() &+ 7
    if location == 0x0C {
      spiceShipmentUnpaid = spiceShipmentUnpaid &+ 1
    }
    commAddPersonSighting((UInt16(location) << 8) | 0x0B)
  }
  
  func shipmentFulfilmentClass() -> UInt8 {
    if (spiceShipmentFulfillment & 0x80) != 0 {
      return 5
    }
    return spiceShipmentFulfillment >> 5
  }
  
  mutating func commAddPersonSighting(_ word: UInt16) {
    if commSightings.count >= 10 {
      return
    }
    commSightings.append(word)
    commSightingCount = UInt8(truncatingIfNeeded: commSightings.count)
    commUnreadCount = commUnreadCount &+ 1
  }
  
  
  func smugglerPointer(_ index: Int) -> UInt16 {
    return smugglerTableOffset &+ UInt16(index) &* smugglerRecordSize
  }
  
  func smugglerIndex(from pointer: UInt16) -> Int? {
    if pointer < smugglerTableOffset {
      return nil
    }
    let relative = pointer &- smugglerTableOffset
    if relative % smugglerRecordSize != 0 {
      return nil
    }
    let index = Int(relative / smugglerRecordSize)
    if index < 0 || index >= smugglers.count {
      return nil
    }
    return index
  }
}
