//
//  RoomPerson.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 13/09/2026.
//


struct DuneRoomPersonFlags: OptionSet {
  let rawValue: UInt8
  
  static let noFlags = DuneRoomPersonFlags([])
  // The static table sets only NPC_DETACH_ON_TRAVEL and NPC_NO_COME_WITH_ME;
  // the rest are written at runtime.
  /// = bit 0x02 — a companion with this bit loses NPC_COMPANION when the player
  /// leaves by ornithopter (npc_travel_detach_companion, seg000:40e6). Static on
  /// the Atreides household and Chani; phase 0x40 sets it on Harah
  /// (seg000:112d) and phase 0x48 clears it on Chani (seg000:114b).
  static let npcDetachOnTravel: DuneRoomPersonFlags = .init(rawValue: 0x02)
  /// = bit 0x04 — an NPC told to STAY HERE in the open desert has found their
  /// own way to the location the player just arrived at: set by the arrival
  /// shuffle when it snaps the stranded entry to the nearest location and that
  /// is the player's (npc_snap_desert_position_to_location, seg000:2234).
  /// Cleared when the shuffle moves the entry on (seg000:21c8) and on every
  /// dialogue close (seg000:97e1); CONDIT reads it through ds:18.
  static let npcLeftBehind: DuneRoomPersonFlags = .init(rawValue: 0x04)
  /// = bit 0x10 — a per-entry story bit: Jessica (seg000:24aa) and Chani
  /// (seg000:1144) once their phase milestone is reached; on the Harkonnen
  /// captain (entry 12) it mirrors the troop's surrendered state
  /// (troop occupation bit 0x10, seg000:31c9) and picks the overpowered sprite
  /// (seg000:3d65) and the greyed COME WITH ME (seg000:90c0).
  static let npcStoryBit: DuneRoomPersonFlags = .init(rawValue: 0x10)
  /// = bit 0x20 — the player has talked to this person (set on every dialogue
  /// close, seg000:97dd).
  static let npcTalkedTo: DuneRoomPersonFlags = .init(rawValue: 0x20)
  /// = bit 0x40 — the person travels with the player (COME WITH ME, seg000:9608;
  /// cleared by npc_clear_travelling). Flips the dialogue verb to STAY HERE and
  /// moves the entry to the second room scan pass (build_room_person_record_b).
  static let npcCompanion: DuneRoomPersonFlags = .init(rawValue: 0x40)
  /// = bit 0x80 — the person never comes along: the COME WITH ME verb is greyed
  /// (seg000:90fd). Static on the Harkonnens, the Emperor and Fremen 2.
  static let npcNoComeWithMe: DuneRoomPersonFlags = .init(rawValue: 0x80)
}


struct DuneRoomPerson {
  /// Matched against `location_and_room` in scan_current_room_npcs.
  var locationAndRoom: UInt16 = 0x3002
  /// Matched against `location_appearance` (data_00006).
  var locationAppearance: UInt16 = 0x0080
  /// seg000 offset of the verb's handler — stored as the second word of the
  /// built command-menu record (room_person_menu_item binds its ported
  /// callback from it) and dispatched directly by the game-area person
  /// click (callback_main_ui_element_21_22). The savegame block carries it
  /// at entry offset +4.
  var handler: UInt16 = 0x0000
  /// = entry word +8 (RoomPerson.time_joined) — game_time when the person
  /// last joined the player (COME WITH ME, npc_refresh_travel_timestamp with
  /// bx=0). loc_094f3 (seed_speaker_condit_fields) seeds for_condit_ds_16
  /// from it while flags bit 0x40 is set.
  var timeJoined: UInt16 = 0
  /// = entry word +0xa (RoomPerson.time_dismissed) — game_time when the
  /// person last stopped travelling (STAY HERE / npc_clear_travelling,
  /// npc_refresh_travel_timestamp with bx=2).
  var timeDismissed: UInt16 = 0
  /// = entry word +0xc (RoomPerson.field_c) — for the Smugglers entry (13)
  /// the seg001 pointer of the smugglers[] record staged for its dialogue
  /// (stage_smuggler_for_condit, seg000:235f); static 0 elsewhere.
  var fieldC: UInt16 = 0
  /// 0..15, the bit position OR-ed into persons_in_room and the offset of the
  /// "&Person" text (0x78..0x87) the verb-menu record displays.
  var personIndex: UInt8 = 0
  /// The NPC_* bits above. NPC_COMPANION splits the two scan passes
  /// (template loc_030b9 / loc_03120): static-data values are 0 /
  /// NPC_DETACH_ON_TRAVEL / NPC_NO_COME_WITH_ME, and NPC_COMPANION is set at
  /// runtime while the person travels with Paul (COME WITH ME, seg000:9608;
  /// cleared by npc_clear_travelling), flipping their dialogue verb to STAY
  /// HERE and their scan match to the second pass.
  var flags: DuneRoomPersonFlags = DuneRoomPersonFlags(rawValue: 0)
  
  init() {
    
  }
  
  init(_ locationAndRoom: UInt16, _ locationAppearance: UInt16, _ handler: UInt16, _ personIndex: UInt8, _ flags: DuneRoomPersonFlags) {
    self.locationAndRoom = locationAndRoom
    self.locationAppearance = locationAppearance
    self.handler = handler
    self.personIndex = personIndex
    self.flags = flags
  }
}

extension DuneDataSegment where T == DuneRoomPerson {
  init(_ offset: UInt16) {
    self.init(wrappedValue: DuneRoomPerson(), offset)
  }
}


let initialRoomPersons: [DuneRoomPerson] = [
  DuneRoomPerson(0x200a, 0x0180, 0x92f2, 0x00, .npcDetachOnTravel),   // Duke Leto Atreides
  DuneRoomPerson(0x2004, 0x0180, 0x92f7, 0x01, .npcDetachOnTravel),   // Lady Jessica Atreides
  DuneRoomPerson(0x2008, 0xff80, 0x92fc, 0x02, .npcDetachOnTravel),   // Thufir Hawat
  DuneRoomPerson(0x2004, 0xff80, 0x9301, 0x03, .npcDetachOnTravel),   // Duncan Idaho
  DuneRoomPerson(0x0002, 0x0d80, 0x9306, 0x04, .noFlags),             // Gurney Halleck
  DuneRoomPerson(0x0402, 0x2e80, 0x930b, 0x05, .noFlags),             // Stilgar
  DuneRoomPerson(0x1002, 0x3f80, 0x9310, 0x06, .noFlags),             // Liet Kynes
  DuneRoomPerson(0x0503, 0x1b80, 0x9315, 0x07, .npcDetachOnTravel),   // Chani
  DuneRoomPerson(0x0703, 0x1180, 0x931a, 0x08, .noFlags),             // Harah
  DuneRoomPerson(0x3002, 0x0280, 0x931f, 0x09, .npcNoComeWithMe),     // Baron Vladimir Harkonnen
  DuneRoomPerson(0x3002, 0x0280, 0x9324, 0x0a, .npcNoComeWithMe),     // Feyd-Rautha Harkonnen
  DuneRoomPerson(0x3002, 0x0280, 0x9329, 0x0b, .npcNoComeWithMe),     // Emperor Shaddam IV
  DuneRoomPerson(0x3002, 0x0080, 0x932e, 0x0c, .noFlags),             // Harkonnen Captain (temp.)
  DuneRoomPerson(0x3002, 0x0080, 0x936f, 0x0d, .noFlags),             // Smugglers (temp.)
  DuneRoomPerson(0x3002, 0x0080, 0x9373, 0x0e, .noFlags),             // Fremen 1 (temp.)
  DuneRoomPerson(0x0202, 0x0080, 0x937e, 0x0f, .npcNoComeWithMe),     // Fremen 2 (temp.)
]
