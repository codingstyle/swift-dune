//
//  Dialogue.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 20/09/2026.
//

enum DialogueTopic: UInt16 {
  case talk0 = 0
  case talk1 = 1
  case talk2 = 2
  case talk3 = 3
  case auto = 4
  case comeWithMe = 5
  case stayHere = 6
  case extra = 7
  
  static let talkMask: UInt8 = 0x80
  static let autoMask: UInt8 = 0x20
}


enum DialogueSpeaker: UInt8 {
  case leto = 0x00
  case jessica = 0x01
  case thufir = 0x02
  case duncan = 0x03
  case gurney = 0x04
  case stilgar = 0x05
  case kynes = 0x06
  case chani = 0x07
  case harah = 0x08
  case baron = 0x09
  case feyd = 0x0A
  case emperor = 0x0B
  case harkonnenCaptain = 0x0C
  case smugglers = 0x0D
  case fremen1 = 0x0E
  case fremen2 = 0x0F
  case narrator = 0x10
}


struct DialogueSentence {
  var flagsLo: UInt8
  let entry2: UInt8
  let conditionId: UInt16
  let phraseId: UInt16
  let fileOffset: UInt32
  
  var event: UInt8 {
    return flagsLo & 0x0F
  }
  
  var isSpoken: Bool {
    return (flagsLo & 0x80) != 0
  }
  
  var isReplayable: Bool {
    return (entry2 & 0x0C) != 0
  }
  
  var isVoiced: Bool {
    return (entry2 & 0x10) != 0
  }
  
  func shouldSkip(mask: UInt8) -> Bool {
    return (flagsLo & 0x80) != 0 && (flagsLo & 0x40) == 0 && (flagsLo & mask) != 0
  }
  
  mutating func markSpoken() {
    flagsLo |= 0x80
  }
}


struct DialogueRecord {
  var sentences: [DialogueSentence]
  let tableOffset: UInt16
  
  var isEmpty: Bool {
    return tableOffset == 0xFFFF || sentences.isEmpty
  }
}


final class Dialogue {
  static let flyoverSlot: UInt16 = (0x10 << 3) | 4
  static let overpowerPrisonerSlot: UInt16 = 0x85
  static let gamePhaseTriggerSlot: UInt16 = 135
  
  private var resource: Resource
  private(set) var records: [DialogueRecord] = []
  private(set) var vocBases: [UInt16] = []
  
  init() {
    self.resource = Resource("DIALOGUE.HSQ")
    parse()
  }
  
  
  static func slot(person: UInt16, topic: UInt16) -> UInt16 {
    return (person << 3) | (topic & 7)
  }
  
  
  func record(at slot: UInt16) -> DialogueRecord? {
    let index = Int(slot)
    if index < 0 || index >= records.count {
      return nil
    }
    let record = records[index]
    if record.isEmpty {
      return nil
    }
    return record
  }
  
  
  func record(person: UInt16, topic: DialogueTopic) -> DialogueRecord? {
    return record(at: Dialogue.slot(person: person, topic: topic.rawValue))
  }
  
  
  func markSpoken(fileOffset: UInt32) {
    var i = 0
    while i < records.count {
      var j = 0
      while j < records[i].sentences.count {
        if records[i].sentences[j].fileOffset == fileOffset {
          records[i].sentences[j].markSpoken()
          return
        }
        j += 1
      }
      i += 1
    }
  }
  
  
  func parse() {
    guard let stream = resource.stream else {
      Logger.shared.log(.error, "DIALOGUE.HSQ: stream not available.")
      return
    }
    
    stream.seek(0)
    
    let firstOffset = stream.readUInt16LE()
    let count = Int(firstOffset / 2)
    
    var offsets = [UInt16]()
    offsets.reserveCapacity(count)
    
    stream.seek(0)
    var i = 0
    while i < count {
      offsets.append(stream.readUInt16LE())
      i += 1
    }
    
    records.removeAll(keepingCapacity: false)
    records.reserveCapacity(count)
    
    i = 0
    while i < count {
      let start = offsets[i]
      if start == 0xFFFF {
        records.append(DialogueRecord(sentences: [], tableOffset: start))
        i += 1
        continue
      }
      
      var end = stream.size
      var j = i + 1
      while j < count {
        if offsets[j] != 0xFFFF {
          end = UInt32(offsets[j])
          break
        }
        j += 1
      }
      
      records.append(parseRecord(stream, start: UInt32(start), end: end, tableOffset: start))
      i += 1
    }
    
    buildVocBases()
    Logger.shared.log(.debug, "Added \(records.count) dialogue records.")
  }
  
  
  private func parseRecord(_ stream: ResourceStream, start: UInt32, end: UInt32, tableOffset: UInt16) -> DialogueRecord {
    stream.seek(start)
    
    var sentences = [DialogueSentence]()
    
    while stream.offset + 2 <= end {
      let word0 = stream.readUInt16LE(peek: true)
      if word0 == 0xFFFF {
        break
      }
      
      if stream.offset + 4 > end {
        break
      }
      
      let fileOffset = stream.offset
      let flagsLo = stream.readByte()
      let condLo = stream.readByte()
      let entry2 = stream.readByte()
      let phraseLo = stream.readByte()
      
      let word1 = UInt16(entry2) | (UInt16(phraseLo) << 8)
      let conditionId = UInt16(condLo) | (UInt16((entry2 >> 6) & 3) << 8)
      let phraseId = (word1.byteSwapped & 0x03FF) | 0x0800
      
      sentences.append(DialogueSentence(
        flagsLo: flagsLo,
        entry2: entry2,
        conditionId: conditionId,
        phraseId: phraseId,
        fileOffset: fileOffset
      ))
    }
    
    return DialogueRecord(sentences: sentences, tableOffset: tableOffset)
  }
  
  
  private func buildVocBases() {
    let personCount = records.count / 8
    vocBases.removeAll(keepingCapacity: false)
    vocBases.reserveCapacity(personCount)
    
    var person = 0
    while person < personCount {
      var base: UInt16 = 0
      var topic = 0
      while topic < 8 {
        let record = records[person * 8 + topic]
        if !record.isEmpty {
          let packed = record.sentences[0].phraseId & 0x03FF
          if packed > 0 {
            base = packed &- 1
          }
          break
        }
        topic += 1
      }
      vocBases.append(base)
      person += 1
    }
  }
}
