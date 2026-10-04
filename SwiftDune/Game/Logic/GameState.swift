//
//  GameState.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 13/09/2026.
//

struct DuneMap {
  
}


struct DuneLocation {
  var status: UInt8 = 0
}

extension DuneDataSegment where T == DuneLocation {
  init(_ offset: UInt16) {
    self.init(wrappedValue: DuneLocation(), offset)
  }
}


struct DuneNearestLocation {
  var distance: UInt16
  var locationPtr: UInt16
  var orientation: DuneOrientation
}

extension DuneDataSegment where T == DuneNearestLocation {
  init(_ offset: UInt16) {
    self.init(wrappedValue: DuneNearestLocation(distance: 0, locationPtr: 0, orientation: .north), offset)
  }
}


extension DuneNearestLocation: DuneDataSegmentValue {
  mutating func write(baseOffset: UInt16, dsOffset: UInt16, value: UInt16, isWord: Bool) -> Bool {
    if dsOffset < baseOffset {
      return false
    }
    
    let relative = dsOffset &- baseOffset
    if isWord {
      if relative == 0 {
        distance = value
        return true
      }
      if relative == 2 {
        locationPtr = value
        return true
      }
      return false
    }
    
    if relative == 4 {
      if let orientation = DuneOrientation(rawValue: UInt8(truncatingIfNeeded: value)) {
        self.orientation = orientation
        return true
      }
    }
    return false
  }
}


struct GameState {
  var mapState: DuneMap
  
  // = seg001:0000 rand_bits — the last word `rand` returned. game_loop
  // refreshes it every pass; seg001:0000 also serves as the seg001 segment
  // base, so most `rand_bits[si]` references in the disasm are addressing
  // other globals at non-zero offsets, not reading this word.
  @DuneDataSegment(0x0000) var randomBits: UInt16
  
  // = seg001:0002 game_time — the in-game clock (16 ticks per day; the low
  // nibble is the time-of-day phase). Static-initialised to 2 (seg001:0002
  // `dw 2`), which is also the value play_intro re-seeds at its exit and
  // start re-seeds again at seg000:001e. The PIT game-clock ISR (not ported)
  // advances it. get_ingame_day_3_periods_later reads (game_time+3)>>4.
  @DuneDataSegment(0x0002) var gameTime: UInt16
  
  // = seg001:0004 location_and_room — the current scene's (location<<8)|room
  // code (the DOS `dx`). draw_location_room records it here; loc_0d41b reads
  // it back via the room navigation stack (get_location_and_room), and
  // add_room_frame_task gates on it.
  @DuneDataSegment(0x0004) var locationAndRoom: UInt16
  
  // = seg001:0006 data_00006 — the current location slot/index (static init
  // 0x180). open_SAL_resource (loc_008f0) sets it from bx; its high byte picks
  // the location's apparence (which SAL file to draw). = `location_appearance` passed
  // to draw_location_room.
  @DuneDataSegment(0x0006) var locationAppearance: UInt16
  
  // = seg001:0008 data_00008 — current room/apparence selector byte (static
  // init 0x20). draw_room_scene and draw_room_game_screen treat 0xff as "no
  // room scene to draw"; the desert walk-out (loc_03fd2) sets it to 0xff and
  // the walk-in arrival (arrive_at_location) restores the location code.
  @DuneDataSegment(0x0008) var data_0008: UInt8
  
  // = seg001:0009 data_00009 — the current location slot byte (the
  // location_appearance high byte), 0xff while out in the desert. Written
  // alongside data_00008 by the walk-out/arrival paths; the NPC shuffle
  // (npc_shuffle_on_arrival) reads it as "where the player is now".
  @DuneDataSegment(0x0009) var data_0009: UInt8
  
  // = seg001:000a bitfield_Paul_events — Paul's story-progress bitfield. Bit 0x10
  // gates the person-0x0e dialogue verb (seg000:90ed: 0x96 vs 0x97).
  @DuneDataSegment(0x000a) var paulFlags: UInt8
  
  @DuneDataSegment(0x000b) var currentRoom: UInt8
  @DuneDataSegment(0x000c) var pendingDestinationRoom: UInt8
  @DuneDataSegment(0x000d) var previousRoom: UInt8
  @DuneDataSegment(0x000e) var personsMet: UInt16 // DuneCharacter flags
  @DuneDataSegment(0x0010) var personsInRoom: UInt16 // DuneCharacter flags
  @DuneDataSegment(0x0012) var personsTravellingWith: UInt16 // DuneCharacter flags
  @DuneDataSegment(0x0014) var personTalkingTo: UInt16 // DuneCharacter flags
  
  // = seg001:0016/0018 for_condit_ds_16 / for_condit_ds_18 — the
  // per-presented-line speaker seeds (loc_094f3, seg000:94f3): ds:16 =
  // game_time minus the speaker's room-person travel timestamp, ds:18 = the
  // speaker's room-person flags byte. Conditions test ds:18 bit 0x40
  // (travelling with Paul — Jessica's "I feel nothing particular in this
  // room" palace-search lines) and bit 0x04 (left in the desert).
  @DuneDataSegment(0x0016) var conditionSpeakerTravelTimestamp: UInt16
  @DuneDataSegment(0x0018) var conditionSpeakerFlags: UInt8
  
  // = seg001:0019 line_spoken_this_conversation — a "has a dialogue line been
  // spoken this conversation" flag: 0 when set_dialogue_speaker starts a
  // conversation (seg000:9417), 0xff once any dialogue line is presented
  // (fire_dialogue_line_event, seg000:a092). A fallback dialogue line tests
  // this == 0 in its CONDIT condition, so the fallback presents only when no
  // other line was presentable this conversation.
  @DuneDataSegment(0x0019) var lineSpokenThisConversation: UInt8
  @DuneDataSegment(0x001a) var relateToArguing_001a: UInt8
  @DuneDataSegment(0x001b) var data_001b: UInt8
  @DuneDataSegment(0x001c) var relatedToPayingSmuggleBills_001c: UInt8
  @DuneDataSegment(0x001d) var currentSmugglerWillingnessToHaggle_001d: UInt8
  @DuneDataSegment(0x001e) var numberOfDaysSinceCurrentSmugglerPreviousEncounter: UInt8
  @DuneDataSegment(0x001f) var relatedToPayingSmugglerBills_001f: UInt8
  @DuneDataSegment(0x0020) var currentSmugglerBillAmount: UInt16
  @DuneDataSegment(0x0022) var numberOfSmugglerBills: UInt8
  
  // = seg001:0023 pending_room_action — the room-transition / dialogue-scan state.
  // ui_click_move_room sets it to 1 to request the room-leave auto-dialogue scan
  // (run_room_leave_dialogue_scan gates on it and clears it), CONDIT condition 0x1c tests it == 1,
  // and the committed move sets it to 5. The dialogue verbs also stage
  // outcome codes here for their record's conditions to read (the Fremen
  // chief's WORK WITH ME charisma check, seg000:95de: 0 pass / 2 refuse).
  @DuneDataSegment(0x0023) var pendingRoomAction: UInt8
  
  // = seg001:0024 for_dialogue_enemies_ds_24 — the location-index byte of
  // the COMM message being viewed (the sighting's high byte), staged for
  // the message dialogue conditions; cleared by comm_return_to_room.
  @DuneDataSegment(0x0024) var commDialogue: UInt8
  
  @DuneDataSegment(0x0025) var numberOfSietchesVisited: UInt8
  @DuneDataSegment(0x0026) var enteringNewSietech: UInt8
  @DuneDataSegment(0x0027) var numberOfSietchesDiscovered: UInt8
  @DuneDataSegment(0x0028) var numberOfRalliedTroops: UInt8
  
  @DuneDataSegment(0x0029) var charisma: UInt8
  @DuneDataSegment(0x002a) var gamePhase: UInt8
  
  @DuneDataSegment(0x002b) var nightAttackStage: UInt8
  // = seg001:11dd _stru_2068D_icon_list[0].index — the ATTACK.HSQ backdrop
  // sprite of the night attack, set by location_arrival_hostility_check
  // from the location type (0x2f sietch, 0x30 village, 0x33 fortress);
  // static 0x31.
  @DuneDataSegment(0x11dd) var nightAttackBackgroundSprite: UInt16
  
  // = seg001:004c related_to_contacting_troops_ds_4c — 0xff while the
  // contacted troop answers from outside the visibility range, so the
  // dialogue record's conditions pick its "out of contact" lines; cleared
  // by map_close_troop_contact_popup.
  @DuneDataSegment(0x004c) var contactingTroops: UInt8
  
  // = seg001:00a0 spice_in_stock — the palace spice stock, stored in batches
  // of 10 kg (a value of 123 is 1230 kg; Duncan's sign appends a "0" to show
  // it in kg). The mining troops pay their whole harvest into it each time
  // period, divided by 10 to convert kg to batches (seg000:701b), the
  // sub-batch kg carried in spice_harvest_remainder.
  @DuneDataSegment(0x00a0) var spiceInStock: UInt16
  
  // = seg001:00a2/00a4 for_condit_area_controlled_by_Atreides/Harkonnen —
  // the map-wide territory percentages compute_area_controlled_percentages
  // (seg000:bfe3) derives from the vegetation-stage bits each new day.
  @DuneDataSegment(0x00a2) var areaControlledByAtreides: UInt16
  @DuneDataSegment(0x00a4) var areaControlledByHarkonnen: UInt16
  
  // = seg001:00a6 for_condit_todays_spice_production_ds_a6 — today's spice
  // production: stock + spice_spent_today - stock_at_last_new_day, clamped
  // at 0 (seg000:1c6e); recompute_condit_statistics keeps the running max
  // within the day.
  @DuneDataSegment(0x00a6) var todaysSpiceProduction: UInt16
  
  // = seg001:00a8 for_condit_harkonnen_spice_production_ds_a8 — the
  // Harkonnen spice production (the SEE RESULTS Harkonnen SPICE PRODUCTION
  // column, ×10 in kg): sum of spice_density/8 over the locations
  // location_is_Atreides_05d36 REJECTS (everything the Harkonnens still
  // exploit) + rand_iterated(sum/16), recomputed each new day
  // (seg000:1cda). Static init 390 (3900 kg at game start).
  @DuneDataSegment(0x00a8) var harkonnenSpiceProduction: UInt16
  
  // = seg001:00aa data_000aa — total population of the troops that are
  // neither Harkonnen nor captured/unrallied (the recompute_condit_
  // statistics scan, seg000:c049).
  @DuneDataSegment(0x00aa) var troopPopulation: UInt16
  
  // = seg001:00ac data_000ac — total population of the Harkonnen-flagged
  // troops (the seg000:c049 scan sums troop byte +0x1a into ds:ac for
  // troops with byte +0x10 bit 0x80, else into ds:aa); static init 0x1b58
  // (7000). Gates the Fremen WORK WITH ME charisma check (seg000:95c4).
  // recompute_condit_statistics refreshes it each new day.
  @DuneDataSegment(0x00ac) var harkonnenTroopPopulation: UInt16
  
  // = seg001:00ae for_condit_previous_day_spice_production_ds_ae — the
  // previous day's production total, exchanged out by the new-day hook
  // (seg000:1c87) to derive the better/lower pair.
  @DuneDataSegment(0x00ae) var previousDaySpiceProduction: UInt16
  
  // = seg001:00b0/00b2 for_condit_spice_production_better/lower_than_
  // previous_day — |production - previous|, one of the pair, the other 0
  // (seg000:1c96).
  @DuneDataSegment(0x00b0) var spiceProductionLowerThanPreviousDay: UInt16
  @DuneDataSegment(0x00b2) var spiceProductionBetterThanPreviousDay: UInt16
  
  // = seg001:00bc/00be/00bf the Emperor's spice-shipment demand state:
  // ds:bc the demanded quantity, ds:be the fulfilment fraction (bit 7 =
  // none paid; static init 0x80, so the first demand announces as the
  // fresh-demand sighting 0x20b rather than the "last shipment wasn't
  // what I demanded" 0x30b), ds:bf the flags (bit 7 = the shipment plot
  // armed, bit 4 = a demand pending). actions_time_in_day_3 (seg000:20a4)
  // rolls the demands; the payment flow (Duncan/CHOAM dialogue) is
  // unported.
  @DuneDataSegment(0x00bc) var spiceShipmentDemand: UInt16
  @DuneDataSegment(0x00be) var spiceShipmentFulfillment: UInt8
  @DuneDataSegment(0x00bf) var spiceShipmentFlags: UInt8
  
  // = seg001:00b4..00ba for_condit_spice_shipment_arguing_related_ds_b4..ba
  // — the four spice amounts Duncan's shipment argument quotes, staged by
  // stage_spice_argue_amounts_with_duncan (seg000:22b1) from the stock and
  // the demand; ds:bf bits 1/2 record which bracket the stock fell in.
  @DuneDataSegment(0x00b4) var spiceShipmentArgumentAmounts: [UInt16] = [0, 0, 0, 0]
  
  // = seg001:009d for_condit_smuggler_dialogue_related_ds_9d — (price & 0x7f)
  // << 1 of the equipment the smuggler offers; 009e for_condit_smuggler_
  // arguing_count_ds_9e — rand_masked(3) haggling rounds; 009f accept_
  // refuse_argue_choice_ds_9f — the ACCEPT/REFUSE/ARGUE verb state (3 =
  // Paul has spice to argue with, 1 = accepted).
  @DuneDataSegment(0x009d) var smugglerDialogueState: UInt8
  @DuneDataSegment(0x009e) var smugglerArgueCount: UInt8
  @DuneDataSegment(0x009f) var smugglerArgueChoice: UInt8
  
  // = seg001:476d argue_menu_with_smuggler — which talk the ACCEPT/REFUSE/
  // ARGUE menu belongs to: 0 = Duncan's shipment offer (dialogue event
  // 0x04), 1 = the smuggler's bill (event 0x05). Event 0x09 reads it.
  @DuneDataSegment(0x476d) var argueMenuWithSmuggler: UInt8
  
  // = seg001:1158 shipment_report_scene_mask — 0xffff once Paul has
  // answered Duncan's offer (seg000:2510); the room-entry scan masks ds:c0
  // with it to run the dining-hall shipment-report scene (seg000:35cf,
  // unported).
  @DuneDataSegment(0x1158) var shipmentReportSceneMask: UInt16
  
  // = seg001:00c0 for_condit_spice_shipment_related_ds_c0 — Duncan's
  // shipment-mission report state: zeroed when his dialogue-line event
  // 0x0f sends him off (seg000:24b3), set from the ds:b4 table when he
  // returns (seg000:250d). The room-entry scan tests it (masked by
  // data_01158) to run the dining-hall shipment-report scene
  // (seg000:35cf); that scene is unported.
  @DuneDataSegment(0x00c0) var spiceShipmentState: UInt16
  
  // = seg001:00c2 final_attack_stage_ds_c2 — the endgame attack-on-the-
  // Harkonnen staging counter; from stage 7 the per-period troop and
  // location event walks stop (seg000:1b5e). The endgame that advances it
  // is unported.
  @DuneDataSegment(0x00c2) var finalAttackStage: UInt8
  
  // = seg001:00c3 spice_shipment_sequence_number_ds_c3 — counts the
  // Emperor's demands; the quantity formula scales with it (seg000:20d2).
  @DuneDataSegment(0x00c3) var spiceShipmentSequence: UInt8
  
  // = seg001:00c4 number_of_sietches_attacked_by_Harkonnen_ds_c4.
  @DuneDataSegment(0x00c4) var numberOfSietchesAttacked: UInt8
  
  // = seg001:00c5 person_marker_base — random base offset for arranging the
  // people standing in a room. Set to rand() at room setup (the arrival
  // handler in tick_in_game_travel, seg000:4fc6), reset to 0 on scene change
  // (seg000:02a2). sal_position_markers reads its low nibble as the `base` in
  // preferred slot = (person_id + base) % count.
  @DuneDataSegment(0x00c5) var personMarkerBase: UInt8
  
  // = seg001:00c6 data_000c6 (book_flags) — the book-screen flags, doubling
  // as the subtitle-suppress gate (any nonzero value makes
  // present_first_matching_dialogue_line skip show_voice_subtitle, and
  // run_game_phase_triggers sets bit 0x80 around the phase-trigger walk).
  // Book bits: 1 = book screen active, 2 = showing the cover, 4 = credits
  // rolling past the last page.
  @DuneDataSegment(0x00c6) var bookFlags: UInt8
  
  // = seg001:00c8 data_000c8 — DOS's comm_sighting_count byte, kept in
  // step with comm_sightings (comm_add_person_sighting); the COMM-room
  // verbs read it (build_room_command_records, dl==8). Inits to 0.
  @DuneDataSegment(0x00c8) var commSightingCount: UInt8
  
  // = seg001:00c8 comm_sighting_count + seg001:1179 comm_sighting_list —
  // the COMM-room person-sighting words ((location index << 8) | person
  // id), max 10, appended by comm_add_person_sighting. Bit 7 of the low
  // byte marks an entry viewed (menu_callback_comms_message_selected); the
  // COMM message list (messages.rs) filters on it.
  //pub(crate) comm_sightings: Vec<u16>,
  var commSightings: [UInt16] = [] // Maximum 10 elements
  
  // = seg001:00c9 for_condit_comms_room_message_count_ds_c9 — the COMM
  // unread badge: incremented per new sighting (seg000:2713), decremented
  // when a new message is viewed (seg000:2941). The COMM verbs grey off it
  // and comm_return_to_room mirrors it into ds:eb.
  //pub(crate) comm_unread_count_ds_c9: u8,
  @DuneDataSegment(0x00c9) var commUnreadCount: UInt8
  
  // The five nearest-location triples condit_scan_nearest_locations
  // (seg000:5274) refreshes from the staged location whenever
  // prepare_location_data_for_condit runs.
  // = seg001:00ca nearest_location_distance_ds_ca — the nearest other
  // location of any kind.
  @DuneDataSegment(0x00ca) var nearestLocation: DuneNearestLocation
  
  // = seg001:00cf days_left_until_spice_shipment — the CONDIT day counter
  // actions_time_in_day_3 maintains while a demand date is ahead.
  @DuneDataSegment(0x00cf) var daysLeftUntilSpiceShipment: UInt8
  
  // = seg001:00d0 nearest_village_distance_ds_d0 — the nearest village
  // (appearance < 0x28, status bit 7 clear).
  @DuneDataSegment(0x00d0) var nearestVillage: DuneNearestLocation
  
  // = seg001:00d5 contact_distance_related_ds_d5 — incremented once per
  // day, but only stored back from 2 up (seg000:1c62), so it stays at its
  // initial value until something else moves it to 1.
  @DuneDataSegment(0x00d5) var contactDistanceRelated: UInt8
  
  // = seg001:00d6 nearest_sietch_distance_ds_d6 — the nearest
  // phase-discoverable sietch (appearance < 0x28, bit 7 set); gates the
  // "There is a sietch very near" messages.
  @DuneDataSegment(0x00d6) var nearestSietch: DuneNearestLocation
  
  // = seg001:00db comm_list_filter_seen_ds_db — the COMM message-list
  // filter: 0 while viewing new messages (rows with sighting bit 7 clear),
  // 0xff while re-viewing already-seen ones.
  @DuneDataSegment(0x00db) var commListSeenMessages: UInt8
  
  // = seg001:00dc nearest_Atreides_area_distance_ds_dc — the nearest
  // Atreides area (appearance >= 0x28, bit 7 clear).
  @DuneDataSegment(0x00dc) var nearestAtreidesArea: DuneNearestLocation
  
  // = seg001:00e1 data_000e1 — the fly-over side flag set by
  // travel_scan_nearby_location (seg000:4156): 0 when the passed location is
  // to the left of the heading, 1 when to the right. Feeds the companion's
  // fly-over dialogue line (the spoken-line tail is not ported yet).
  @DuneDataSegment(0x00e1) var flyOverSideFlags: UInt8
  
  // = seg001:00e2 nearest_Harkonnen_area_distance_ds_e2 — the nearest
  // Harkonnen area (appearance >= 0x28, bit 7 set); the ESPIONAGE
  // occupation and the Harkonnen-captain dialogue need its distance < 0x1e.
  @DuneDataSegment(0x00e2) var nearestHarkonnenArea: DuneNearestLocation
  
  // = seg001:00e7 Paul_found_unconscious_in_desert_ds_e7 — cleared by the
  // desert walk-out (seg000:3fd2) and after an auto-dialogue line
  // (seg000:354c).
  @DuneDataSegment(0x00e7) var paulFoundUnconscious: UInt8
  
  // = seg001:00e8 _byte_1F598_ui_hud_head_index.
  @DuneDataSegment(0x00e8) var uiHudHeadIndex: UInt8
  
  // = seg001:00e9 for_condit_ds_e9 — the person id of the COMM message
  // being presented (0 between messages); the message dialogue records'
  // conditions read it.
  @DuneDataSegment(0x00e9) var commPersonId: UInt8
  
  // = seg001:00ea data_000ea (signed).
  @DuneDataSegment(0x00ea) var data_00ea: Int8
  
  // = seg001:00eb for_condit_presence_of_comms_room_message_which_needs_
  // viewing_there_ds_eb — comm_return_to_room and the vision dream mirror
  // the unread state here for CONDIT.
  @DuneDataSegment(0x00eb) var commMessageNeedsViewing: UInt8
  
  // = seg001:00ed/00ee for_condit_related_to_overpowering_Harkonnen_captain
  // — seeded by the captain classification (0xff when surrendered, else the
  // troop's motivation; the pair word), consumed by the OVERPOWER THE
  // PRISONER flow (seg000:9584).
  @DuneDataSegment(0x00ed) var data_000ed: UInt8
  @DuneDataSegment(0x00ee) var data_000ee: UInt16
  
  // = seg001:00f4 desert_exhaustion_counter — Paul's desert-exhaustion
  // latch: +1 per compass step outdoors, saturating at
  // DESERT_EXHAUSTION_MAX; the hourly decrement (run_events_for_current_
  // time_period) snaps any value below DESERT_EXHAUSTION_GAUNT_THRESHOLD
  // to 0, so it holds either "recently marched hard" (16..=20) or 0.
  @DuneDataSegment(0x00f4) var desertExhaustionCounter: UInt8
  
  // = seg001:00f5 for_condit_desert_walk_related_ds_f5 — cleared with the
  // counter when the per-period countdown drops below
  // DESERT_EXHAUSTION_GAUNT_THRESHOLD (seg000:1b36); Jessica's desert
  // dialogue reads it.
  @DuneDataSegment(0x00f5) var jessicaCommentedOnExhaustion: UInt8
  
  // = seg001:00f7 for_condit_Gurney_Stilgar_Chani_at_location_ds_f7 — the
  // named NPCs at the staged location, bit person_index
  // (condit_stage_named_npcs_at_location).
  @DuneDataSegment(0x00f7) var gurneyStilgarChaniAtLocation: UInt8
  
  // = seg001:00f2 for_condit_Chani_prisoner_location_area_and_name_ds_f2 —
  // (first_name << 8) | last_name of the sietch Chani is held prisoner in,
  // set by the phase-0x64 callback.
  @DuneDataSegment(0x00f2) var chaniPrisonerLocation: UInt16
  
  // = seg001:00f6 for_condit_Paul_next_to_harvester_ds_f6 — set by
  // desert_harvester_check while the player stands at a location whose
  // spice-mining troop has a working harvester.
  @DuneDataSegment(0x00f6) var paulNextToHarvester: UInt8
  
  // = seg001:00f8 number_of_locations_with_illness / seg001:00f9
  // Chani_troop_illness_cure_progress / seg001:11db PTR_Location_latest_
  // location_with_illness — the phase-5c/5d illness-cure subplot state:
  // the picker (seg000:1e43) makes the strongest non-fortress ill, Chani
  // parked there advances the cure by 8 per period until it wraps to 0
  // (seg000:1eda). The latest-ill pointer keeps the DOS location-ptr
  // encoding (0 = none).
  @DuneDataSegment(0x00f8) var numberOfLocationsWithIllness: UInt8
  @DuneDataSegment(0x00f9) var chaniTroopIllnessCureProgress: UInt8
  @DuneDataSegment(0x00fa) var latestLocationWithIllness: UInt16
  
  // = seg001:00fb data_000fb — toggle between the room/dialogue view and the
  // globe/map view (static init 0xff). ui_toggle_room_view negs it each call:
  // a non-negative result shows the room view, a negative one the map.
  @DuneDataSegment(0x00fb) var roomViewToggle: UInt8
  
  // = seg001:00fc data_000fc — a constant early-game flag (static
  // init 1, no DOS writers); CONDIT condition 1 (`byte ds:[fc]`) gates the
  // first greeting on it.
  @DuneDataSegment(0x00fc) var condition1: UInt8
  
  // = seg001:00fd for_condit_battle_related_ds_fd — the night attack's
  // battle gauge byte (location_seed_battle_gauge: the gauge | 1).
  @DuneDataSegment(0x00fd) var locationSeedBattleGauge: UInt8
  
  // = seg001:00fe game_phase_copy_ds_fe — the new-day hook's copy of
  // game_phase; a mismatch resets days_since_last_game_phase_change
  // (seg000:1c46).
  @DuneDataSegment(0x00fe) var gamePhaseCopy: UInt8
  
  // = seg001:00ff number_of_days_since_last_game_phase_change_ds_ff — zeroed
  // on every phase change (the event-0x0b callback and
  // set_game_phase_and_trigger_callbacks) and incremented by the new-day
  // hook (run_events_new_day, seg000:1c46).
  @DuneDataSegment(0x00ff) var daysSinceLastGamePhaseChange: UInt8
  
  @DuneDataSegment(0x0100) var locations: [DuneLocation] = Array.init(repeating: DuneLocation(), count: 70)
  @DuneDataSegment(0x08aa) var troops: [DuneTroop] = initialTroops
  
  // = seg001:0e30/0e32 _word_20E30_globe_param_3 / _word_20E32_globe_param_4
  // — the map position the spice-density overlay is centred on, exchanged
  // with the live zoomed-globe position around its draw (loc_0b69a).
  @DuneDataSegment(0x0e30) var globeParam3: UInt16
  @DuneDataSegment(0x0e32) var globeParam4: Int16
  
  // = seg001:0fd8 room_persons — the 16-entry room-person table walked by
  // scan_current_room_npcs. Mutable copy of ROOM_PERSON_TABLE_INIT;
  // init_room_persons rewrites entries 12..16 (addresses data_0109a / 10aa /
  // 10ba / 10ca) and its special-room branch (init_room_persons_special)
  // also touches entries 12, 14, 15 plus (selectively) 13.
  @DuneDataSegment(0x0fd8) var roomPersons: [DuneRoomPerson] = initialRoomPersons
  
  // = seg001:10d8 smugglers — the six smuggler inventories (region,
  // haggling, stock and prices); the new-day hook restocks them
  // (seg000:1cae).
  @DuneDataSegment(0x10d8) var smugglers: [DuneSmuggler] = initialSmugglers
  
  // = seg001:113f current_smuggler_ptr — the smugglers[] record Duncan's
  // bill scan rotates through (seg000:2282..229f); static init = the
  // table's first record. Kept as the DOS seg001 pointer (see
  // smugglers::smuggler_ptr) so the save image carries it verbatim.
  //pub(crate) current_smuggler_ptr: u16,
  @DuneDataSegment(0x113f) var currentSmugglerPtr: UInt16 // TODO: ref ptr or index ?
  
  // = seg001:1141 array_likelihood_of_worm_related_spice_mining_troop_
  // events_by_region — [0] is the base event probability (incremented by
  // the phase-0x4c and 0x5c callbacks; the smuggler dialogue also reads
  // it), [1..12] the per-region base indexed by Location.first_name.
  @DuneDataSegment(0x1141) var wormEventLikelihoodByRegion: [UInt8] = Array.init(repeating: 0, count: 13)
  
  // = seg001:114e current_location_ptr — the locations[] index of the
  // location the player is currently inside. Recomputed on every scene open
  // (loc_008f0, the port's draw_location_room) and set on walk-in arrival
  // (arrive_at_location).
  @DuneDataSegment(0x114e) var currentLocationIndex: UInt16
  
  // Dialogue session (not a single DOS ds word; see DialogueEvents.swift).
  var currentSpeakerId: UInt8 = 0
  var dialogueInterruptGate: UInt8 = 0
  var dialogueEndRequest: UInt8 = 0
  var spiceSpentToday: UInt16 = 0
  var locationVisibilityDistance: UInt16 = 0
  var conditStagedLocation: UInt16 = 0
  var stagedNameLocation: UInt16 = 0
  var stringSubstIds: [UInt16] = Array(repeating: 0, count: 8)
  var pendingRoomScreenRequest: UInt8 = 0
  var spiceShipmentUnpaid: UInt8 = 0
  var voiceSubtitleMode: UInt8 = 0
  var headSignArmed: Bool = false
  var stilgarWaterOfLifePending: Bool = false
  var showLocationOnMapRequested: Bool = false
  var pendingCutscene: DialogueCutscene?
  var dialoguePlayedLog: [UInt16] = []
  
  
  mutating func update(_ offset: UInt16, _ value: UInt16, isWord: Bool = false) {
    if applySegmentFields(Self.uint8Fields, offset, value, isWord) { return }
    if applySegmentFields(Self.uint16Fields, offset, value, isWord) { return }
    if applySegmentFields(Self.int8Fields, offset, value, isWord) { return }
    if applySegmentFields(Self.int16Fields, offset, value, isWord) { return }
    if applySegmentFields(Self.uint8ArrayFields, offset, value, isWord) { return }
    if applySegmentFields(Self.uint16ArrayFields, offset, value, isWord) { return }
    _ = applySegmentFields(Self.nearestFields, offset, value, isWord)
  }
  
  mutating func update<T: FixedWidthInteger>(_ wrapper: inout DuneDataSegment<T>, _ value: T) {
    wrapper.wrappedValue = value
  }
  
  
  private mutating func applySegmentFields<T: DuneDataSegmentValue>(
    _ fields: [WritableKeyPath<GameState, DuneDataSegment<T>>],
    _ offset: UInt16,
    _ value: UInt16,
    _ isWord: Bool
  ) -> Bool {
    var i = 0
    while i < fields.count {
      let keyPath = fields[i]
      var wrapper = self[keyPath: keyPath]
      if wrapper.write(dsOffset: offset, value: value, isWord: isWord) {
        self[keyPath: keyPath] = wrapper
        return true
      }
      i += 1
    }
    return false
  }
  
  private static let uint8Fields: [WritableKeyPath<GameState, DuneDataSegment<UInt8>>] = [
    \._data_0008, \._data_0009, \._paulFlags, \._currentRoom,
    \._pendingDestinationRoom, \._previousRoom, \._conditionSpeakerFlags,
    \._lineSpokenThisConversation, \._relateToArguing_001a, \._data_001b,
    \._relatedToPayingSmuggleBills_001c, \._currentSmugglerWillingnessToHaggle_001d,
    \._numberOfDaysSinceCurrentSmugglerPreviousEncounter, \._relatedToPayingSmugglerBills_001f,
    \._numberOfSmugglerBills, \._pendingRoomAction, \._commDialogue,
    \._numberOfSietchesVisited, \._enteringNewSietech, \._numberOfSietchesDiscovered,
    \._numberOfRalliedTroops, \._charisma, \._gamePhase, \._nightAttackStage,
    \._contactingTroops, \._smugglerDialogueState, \._smugglerArgueCount,
    \._smugglerArgueChoice, \._spiceShipmentFulfillment, \._spiceShipmentFlags,
    \._finalAttackStage, \._spiceShipmentSequence, \._numberOfSietchesAttacked,
    \._personMarkerBase, \._bookFlags, \._commSightingCount, \._commUnreadCount,
    \._daysLeftUntilSpiceShipment, \._contactDistanceRelated, \._commListSeenMessages,
    \._flyOverSideFlags, \._paulFoundUnconscious, \._uiHudHeadIndex, \._commPersonId,
    \._commMessageNeedsViewing, \._data_000ed, \._desertExhaustionCounter,
    \._jessicaCommentedOnExhaustion, \._paulNextToHarvester, \._gurneyStilgarChaniAtLocation,
    \._numberOfLocationsWithIllness, \._chaniTroopIllnessCureProgress, \._roomViewToggle,
    \._condition1, \._locationSeedBattleGauge, \._gamePhaseCopy,
    \._daysSinceLastGamePhaseChange, \._argueMenuWithSmuggler
  ]
  
  private static let uint16Fields: [WritableKeyPath<GameState, DuneDataSegment<UInt16>>] = [
    \._randomBits, \._gameTime, \._locationAndRoom, \._locationAppearance,
    \._personsMet, \._personsInRoom, \._personsTravellingWith, \._personTalkingTo,
    \._conditionSpeakerTravelTimestamp, \._currentSmugglerBillAmount, \._spiceInStock,
    \._areaControlledByAtreides, \._areaControlledByHarkonnen, \._todaysSpiceProduction,
    \._harkonnenSpiceProduction, \._troopPopulation, \._harkonnenTroopPopulation,
    \._previousDaySpiceProduction, \._spiceProductionLowerThanPreviousDay,
    \._spiceProductionBetterThanPreviousDay, \._spiceShipmentDemand, \._spiceShipmentState,
    \._data_000ee, \._chaniPrisonerLocation, \._latestLocationWithIllness,
    \._globeParam3, \._currentSmugglerPtr, \._currentLocationIndex,
    \._shipmentReportSceneMask, \._nightAttackBackgroundSprite
  ]
  
  private static let int8Fields: [WritableKeyPath<GameState, DuneDataSegment<Int8>>] = [
    \._data_00ea
  ]
  
  private static let int16Fields: [WritableKeyPath<GameState, DuneDataSegment<Int16>>] = [
    \._globeParam4
  ]
  
  private static let uint8ArrayFields: [WritableKeyPath<GameState, DuneDataSegment<[UInt8]>>] = [
    \._wormEventLikelihoodByRegion
  ]
  
  private static let uint16ArrayFields: [WritableKeyPath<GameState, DuneDataSegment<[UInt16]>>] = [
    \._spiceShipmentArgumentAmounts
  ]
  
  private static let nearestFields: [WritableKeyPath<GameState, DuneDataSegment<DuneNearestLocation>>] = [
    \._nearestLocation, \._nearestVillage, \._nearestSietch,
    \._nearestAtreidesArea, \._nearestHarkonnenArea
  ]
}
