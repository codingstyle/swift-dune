//
//  Dialogue.swift
//  SwiftDune
//
//  The original dialogue engine: CONDIT.HSQ conditions over the data
//  segment, DIALOGUE.HSQ line lists (17 characters x 8 lists of 4-byte
//  entries) with "said" flags, and the line actions that move the story.
//
//  Port of the ScummVM Dune engine's dialogue.cpp (Conditions, Dialogue,
//  Conversation) and GameScreen::storyEvent / setGamePhase /
//  runPhaseTriggers (scene.cpp).
//

import Foundation


/// CONDIT.HSQ: condition k (from 1) starts at word (k - 1) * 2. A condition
/// is an operand, then (operator, operand) pairs, ended by 0xFF.
final class Conditions {
    private let data: [UInt8]

    init() {
        data = Resource("CONDIT.HSQ").unpackedData
    }

    var count: Int { data.count >= 2 ? (Int(data[0]) | Int(data[1]) << 8) / 2 : 0 }

    private func operand(_ position: inout Int, _ world: World) -> UInt16? {
        guard position < data.count else { return nil }
        let kind = data[position]
        position += 1
        if kind < 0x80 {
            guard position < data.count else { return nil }
            let index = Int(data[position])
            position += 1
            return kind == 1 ? UInt16(world.b(index)) : world.w(index)
        } else if kind == 0x80 {
            guard position < data.count else { return nil }
            defer { position += 1 }
            return UInt16(data[position])
        } else {
            guard position + 1 < data.count else { return nil }
            defer { position += 2 }
            return UInt16(data[position]) | UInt16(data[position + 1]) << 8
        }
    }

    /// off_1A376: comparisons give 0xFFFF or 0; jb/ja unsigned, jle/jge signed.
    private static func apply(_ op: UInt8, _ left: UInt16, _ right: UInt16) -> UInt16 {
        switch op & 0x1F {
        case 0x00: return left == right ? 0xFFFF : 0
        case 0x02: return left < right ? 0xFFFF : 0
        case 0x04: return left > right ? 0xFFFF : 0
        case 0x06: return left != right ? 0xFFFF : 0
        case 0x08: return Int16(bitPattern: left) <= Int16(bitPattern: right) ? 0xFFFF : 0
        case 0x0A: return Int16(bitPattern: left) >= Int16(bitPattern: right) ? 0xFFFF : 0
        case 0x0C: return left &+ right
        case 0x0E: return left &- right
        case 0x10: return left & right
        case 0x12: return left | right
        default: return 0
        }
    }

    func evaluate(_ index: Int, _ world: World) -> Bool {
        if index == 0 { return true }
        guard index <= count else { return false }
        var position = Int(data[(index - 1) * 2]) | Int(data[(index - 1) * 2 + 1]) << 8
        guard var left = operand(&position, world) else { return false }

        var stack: [(left: UInt16, op: UInt8)] = []
        while true {
            guard position < data.count else { return false }
            let op = data[position]
            position += 1
            if op == 0xFF { break }
            if op & 0x80 != 0 {
                // Binds tighter: keep what we have, start a new left side.
                stack.append((left, op))
                guard let next = operand(&position, world) else { return false }
                left = next
            } else {
                guard let right = operand(&position, world) else { return false }
                left = Conditions.apply(op, left, right)
            }
        }
        // Stacked operations resolve from the oldest on (loc_1A3CB).
        if !stack.isEmpty {
            var accumulated = stack[0].left
            for i in 0..<stack.count {
                let next = i + 1 < stack.count ? stack[i + 1].left : left
                accumulated = Conditions.apply(stack[i].op, accumulated, next)
            }
            left = accumulated
        }
        return left != 0
    }
}


/// DIALOGUE.HSQ, with the "said" bits the game writes into it (saves keep
/// the whole table).
final class DialogueData {
    static let listsPerCharacter = 8

    struct Entry {
        var offset: Int
        var flags: UInt8        // b0: bit 7 said, bit 6 repeatable, 4-5 mask group, 0-3 action
        var flags2: UInt8       // b2
        var condition: Int
        var sentence: Int       // 0-based phrase index

        var said: Bool { flags & 0x80 != 0 }
        var repeatable: Bool { flags & 0x40 != 0 }
        var action: Int { Int(flags & 0x0F) }
        /// 1 politics, 2 Paul on Dune, 3 spice, 4 the Fremen.
        var topic: Int { Int(flags2 >> 2) & 0x0F }
    }

    private(set) var data: [UInt8]
    private var initial: [UInt8]
    /// Entries from this offset on use PHRASEx2 (floppy 0x920).
    private(set) var split = 0

    init() {
        data = Resource("DIALOGUE.HSQ").unpackedData
        initial = data
        if data.count >= 0x62 {
            split = Int(data[0x60]) | Int(data[0x61]) << 8
        }
    }

    func reset() { data = initial }

    /// A save's copy, said flags included.
    func setData(_ saved: [UInt8]) {
        if saved.count == data.count { data = saved }
    }

    func listOffset(character: Int, list: Int) -> Int {
        let index = character * DialogueData.listsPerCharacter + list
        guard data.count >= 2, index < (Int(data[0]) | Int(data[1]) << 8) / 2 else { return 0 }
        let offset = Int(data[index * 2]) | Int(data[index * 2 + 1]) << 8
        return offset + 1 < data.count ? offset : 0
    }

    func entry(at offset: Int) -> Entry? {
        guard offset > 0, offset + 4 <= data.count else { return nil }
        if data[offset] == 0xFF && data[offset + 1] == 0xFF { return nil }
        let b2 = data[offset + 2]
        let number = Int(b2 & 3) << 8 | Int(data[offset + 3])
        return Entry(offset: offset, flags: data[offset], flags2: b2,
                     condition: Int(b2 >> 6) << 8 | Int(data[offset + 1]),
                     sentence: number > 0 ? number - 1 : 0)
    }

    func secondPhraseFile(_ offset: Int) -> Bool { split > 0 && offset >= split }

    func markSaid(_ offset: Int) {
        if offset + 4 <= data.count { data[offset] |= 0x80 }
    }
}


/// One conversation: walks a character's lists, shows the first line whose
/// condition holds, runs its action when its last page has been read.
final class Conversation {
    private let story: Story
    private(set) var character: Int
    private var list: Int
    private var searchOffset = 0
    private let mask: UInt8
    private let oneList: Bool
    private let single: Bool

    private var current: DialogueData.Entry?
    private var pendingFinish = false
    private var endAfter = false
    private var answered = false
    private var pages: [String] = []
    private var pageIndex = 0
    private(set) var active = true
    /// Action 4/5 stopped the talk for ACCEPT / REFUSE / ARGUE (ds:9F).
    private(set) var awaitingChoice = false

    /// Actions 1/2/7 set it: 0xFF the verb succeeds, 0 a refusal, 0x80
    /// show equipment.
    private(set) var gate: UInt8 = 0xFF

    init(story: Story, character: Int, list: Int, mask: UInt8 = 0x80, oneList: Bool = false, single: Bool = false) {
        self.story = story
        self.character = character
        self.list = list
        self.mask = mask
        self.oneList = oneList
        self.single = single
        // sub_193DF: met, and the one Paul talks to.
        let world = story.world
        let bit: UInt16 = character < 16 ? UInt16(1) << UInt16(character) : 0
        world.setW(0x0E, world.w(0x0E) | bit)
        world.setW(0x14, bit)
        if character == World.thufir {
            world.thufirSpeaks() // seg000:9f40: the final attack's stage 5
        } else if character == World.captain {
            world.prepareCaptain() // seg000:932e: the fort he knows of
        }
    }

    /// The next page to show, or nil when the conversation is over.
    func next() -> String? {
        if awaitingChoice { return nil }
        while active {
            if pageIndex < pages.count {
                defer { pageIndex += 1 }
                return pages[pageIndex]
            }
            if pendingFinish {
                finishEntry()
                if awaitingChoice { return nil } // the host shows the bargaining rows
                if endAfter || single { break }
            }
            if answered || !findEntry() { break }
        }
        active = false
        story.world.setW(0x14, 0)
        return nil
    }

    func endAfterLine() { endAfter = true }

    /// After ACCEPT / REFUSE / ARGUE: the talk goes on (loc_19472).
    func resume() { awaitingChoice = false }

    /// Runs the shown line's action now (a verb reads the gate right after
    /// the answer appears, seg000:95f7).
    func finishPending() {
        guard pendingFinish else { return }
        finishEntry()
        if single || endAfter { answered = true }
    }

    private func findEntry() -> Bool {
        let dialogue = story.dialogue
        while true {
            var offset = searchOffset != 0 ? searchOffset : dialogue.listOffset(character: character, list: list)
            while let entry = dialogue.entry(at: offset) {
                // loc_19FAB: a line already said is skipped unless it is
                // repeatable or outside the current mask.
                let skip = entry.said && !entry.repeatable && (entry.flags & mask) != 0
                if !skip && story.conditions.evaluate(entry.condition, story.world) {
                    current = entry
                    searchOffset = offset + 4
                    pendingFinish = true
                    let text = GameText.shared.phrase(entry.sentence, secondFile: dialogue.secondPhraseFile(offset))
                    pages = text.split(separator: GameText.pageBreak, omittingEmptySubsequences: true).map(String.init)
                    pageIndex = 0
                    DuneEngine.shared.logger.log(.info, "Dialogue: char \(character) list \(list) entry \(offset) cond \(entry.condition) phrase \(entry.sentence)\(dialogue.secondPhraseFile(offset) ? " (x2)" : "") action \(entry.action)")
                    return true
                }
                offset += 4
            }
            // The next list while its number is not a multiple of 4.
            searchOffset = 0
            list += 1
            if oneList || list & 3 == 0 || list >= DialogueData.listsPerCharacter { return false }
        }
    }

    private func finishEntry() {
        pendingFinish = false
        guard let entry = current else { return }
        let wasSaid = entry.said
        applyAction(entry, wasSaid: wasSaid)
        story.dialogue.markSaid(entry.offset)
        if entry.topic != 0 && !wasSaid {
            story.notebook.append(UInt16(character << 11 | entry.offset / 4))
        }
    }

    private func applyAction(_ entry: DialogueData.Entry, wasSaid: Bool) {
        switch entry.action {
        case 0, 10: break                 // 10: CD lip sync
        case 1: gate = 0xFF
        case 2: gate = 0
        case 6: endAfter = true
        case 7: gate = 0x80
        case 4, 5:
            // 0xA244 / 0xA248: the bargaining question (Duncan or a smuggler).
            story.world.setB(World.choice, 0)
            awaitingChoice = true
        case 14:
            if !wasSaid { story.world.setB(0xC2, story.world.b(0xC2) &+ 1) }
        default:
            story.event(entry.action, wasSaid: wasSaid, speaker: character, conversation: self)
        }
    }
}


/// Story state around the dialogue: phase changes, phase triggers and the
/// line events (actions 3, 8, 9, 11, 12, 15).
final class Story {
    static let shared = Story()

    let world = World.shared
    let dialogue = DialogueData()
    let conditions = Conditions()
    /// Lines recorded for the book: character << 11 | entry offset / 4.
    var notebook: [UInt16] = []
    /// Scripted scene (CD code offset) a line or phase asked for.
    private(set) var pendingScene: UInt16 = 0

    /// The scene to play next, once (the game starts it when idle).
    func takePendingScene() -> UInt16? {
        guard pendingScene != 0 else { return nil }
        defer { pendingScene = 0 }
        return pendingScene
    }

    private init() {}

    func newGame() {
        dialogue.reset()
        notebook = []
        pendingScene = 0
        // The executable runs the triggers twice when a game starts.
        runPhaseTriggers()
        runPhaseTriggers()
    }

    var phase: UInt8 { world.b(World.phase) }

    /// After a load: the book's journal from the said lines with a topic.
    func rebuildNotebook() {
        notebook = []
        for character in 0..<17 {
            for list in 0..<DialogueData.listsPerCharacter {
                var offset = dialogue.listOffset(character: character, list: list)
                while let entry = dialogue.entry(at: offset) {
                    if entry.said && entry.topic != 0 {
                        let record = UInt16(character << 11 | offset / 4)
                        if !notebook.contains(record) { notebook.append(record) }
                    }
                    offset += 4
                }
            }
        }
    }

    /// Does `character` have a line in `list` whose condition holds now?
    func hasLine(character: Int, list: Int, mask: UInt8 = 0x80) -> Bool {
        var offset = dialogue.listOffset(character: character, list: list)
        while let entry = dialogue.entry(at: offset) {
            let skip = entry.said && !entry.repeatable && (entry.flags & mask) != 0
            if !skip && conditions.evaluate(entry.condition, world) { return true }
            offset += 4
        }
        return false
    }

    /// setGamePhase: phases only go up; run the triggers, then the phase's
    /// callback when it is a multiple of 4 up to 0x6C.
    func setGamePhase(_ newPhase: UInt8) {
        guard newPhase > phase else { return }
        world.setB(World.phase, newPhase)
        world.setB(0xFF, 0)
        DuneEngine.shared.logger.log(.info, "Story: phase -> \(String(newPhase, radix: 16))")
        runPhaseTriggers()
        if newPhase <= 0x6C && newPhase & 3 == 0 {
            let result = world.phaseCallback(newPhase)
            if result.cutscene != 0 { pendingScene = result.cutscene }
            if result.vision != 0 { world.queueVision(result.vision) }
        }
    }

    /// present_game_phase_trigger_line (seg000:96b5): character 16 list 7,
    /// mask 0x80; the line is not shown, only its action fires.
    func runPhaseTriggers() {
        let triggers = Conversation(story: self, character: 16, list: 7, mask: 0x80, oneList: true)
        if triggers.next() != nil {
            _ = triggers.next()
        }
        world.setW(0x14, 0)
    }

    fileprivate func event(_ action: Int, wasSaid: Bool, speaker: Int, conversation: Conversation) {
        // 3, 8, 9 and 15 run every time; 11 and 12 only the first time.
        if wasSaid && ![3, 8, 9, 15].contains(action) { return }
        switch action {
        case 11:
            // phase + 1, the triggers; Duncan comes at phase 1 (seg000:100b).
            world.setB(World.phase, phase &+ 1)
            world.setB(0xFF, 0)
            DuneEngine.shared.logger.log(.info, "Story: phase -> \(String(phase, radix: 16))")
            if phase == 1 {
                world.setCharacterByte(World.duncan, 3, 1)
            }
            runPhaseTriggers()
        case 12:
            setGamePhase((phase & 0xFC) &+ 4)
        case 3:
            pendingScene = world.phaseSceneScript
            conversation.endAfterLine()
        case 8 where speaker == World.jessica:
            world.raiseContactRange()
        case 15 where speaker == World.jessica:
            world.setB(0xF5, world.b(0xF5) &+ 1)
        case 8 where speaker == World.duncan:
            world.duncanOffers()
        case 9 where speaker == World.duncan:
            world.duncanAccept()
        case 15 where speaker == World.duncan:
            let closing = world.duncanClosing()
            world.addSighting(closing.sighting)
            if closing.endTalk { conversation.endAfterLine() }
        case 8 where speaker == World.stilgar:
            world.stilgarWaterOfLife() // seg000:2ccf; a death sets pendingEnding 176
        case 9 where speaker == World.stilgar:
            world.finalAttackTroops() // seg000:2d2c
        case 8 where speaker == World.captain:
            // Character 12 shows the hidden place whose pointer is at ds:11CE.
            let pointer = Int(world.w(0x11CE))
            if pointer >= Location.tableOffset && (pointer - Location.tableOffset) % Location.recordSize == 0 {
                world.reveal([(pointer - Location.tableOffset) / Location.recordSize])
            }
        default:
            DuneEngine.shared.logger.log(.warn, "Story: event \(action) of speaker \(speaker) not ported yet")
        }
    }
}
