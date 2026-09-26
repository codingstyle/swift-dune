//
//  Game.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 24/08/2024.
//

import Foundation

final class Game: DuneNode {
    private var mainMenuItems: [UInt16] = [141, 109]
    private var mainMenuCaptions: [String]? = nil
    // Paul's position, exits, sheets and who stands where come from the
    // executable's data segment (World), not from hand-copied tables.
    private let world = World.shared

    /// Room number (1-based) of the current place, ds:4.
    private var currentGameRoom: Int {
        get { world.room }
        set { world.setRoom(newValue) }
    }
    private var dialogueCharacter: DuneCharacter?
    private var lastDialogueCharacter: DuneCharacter?
    private var dialogueMenuItems: [UInt16] = []
    private var dialogueContext: DialogueContext = .palace
    private var dialoguePhraseOverride: Int?
    /// The DIALOGUE.HSQ conversation in progress (TALK TO ME).
    private var conversation: Conversation?
    private let story = Story.shared

    private enum DialogueContext: Equatable {
        case comm
        case palace
        case sietch
        case troop
        case shipment
    }
    private let menuRect = DuneRect(92, 159, 136, 40)
    // Exact English COMMAND1.HSQ records used by the original command menus.
    private let sietchOrderItems: [UInt16] = [67, 68, 69, 70, 71]
    private let sietchOccupationItems: [UInt16] = [106, 107, 108, 71]
    private let sietchMovementItems: [UInt16] = [77, 78, 79, 80, 81]

    private enum SietchMenuMode {
        case root
        case orders
        case occupation
        case movement
    }

    private var sietchMenuMode: SietchMenuMode = .root
    private var musicStarted = false
    /// The song playing (MusicSituation decides).
    private var currentSong: String?
    private var desertActive = false
    private var sietchActive = false
    /// The flat map is open (SEE DUNE MAP, or choosing where to fly).
    private var mapActive = false
    /// The floppy's travel step: 8 landscape frames of 16 ticks (640 ms);
    /// the CD's is 0x300 ticks (3.83 s).
    private static let stepSeconds = 0.64
    /// Flying to a place (index) or to a desert point (-1): arrival time.
    private var flight: (destination: Int, cells: Int, arrival: TimeInterval)?
    private var flightPoint: (latitude: Int, longitude: UInt16)?
    private var clock: TimeInterval = 0
    /// Paul in the open desert (ds:8 = 0xFF).
    private var inDesert = false
    /// CALL A WORM chose the map: the next trip rides a worm (no ornithopter).
    private var riding = false
    /// MOVE TROOP chose the map: the destination is the troop's (map "Done").
    private var movingTroop: Int?
    /// How long Paul has waited in a room or the desert with nothing open
    /// (idle_room_message_check, seg000:2b2a); input resets it.
    private var idleTime: TimeInterval = 0
    /// A vision dream is on screen (VIS.HSQ behind the line).
    private var dreaming = false
    /// A scripted scene: its bytes, the next one, the room to return to.
    private var scene: [UInt8] = []
    private var sceneCursor = 0
    private var sceneActive = false
    private var sceneReturnRoom = 0
    private var sceneWaiting = false
    private let gameState = GameState.shared
    
    init() {
        super.init("Game")
    }

  
    override func onEnable() {
      engine.palette.clear()
      world.reset() // new game: the executable's data, Paul in the throne room
      conversation = nil
      if let time = DevHarness.shared.startTime {
          world.setW(World.gameTime, time)
      }
      dialogueCharacter = nil
      lastDialogueCharacter = nil
      dialogueMenuItems = []
      mainMenuCaptions = nil
      dialogueContext = .palace
      dialoguePhraseOverride = nil
      musicStarted = false
      currentSong = nil
      desertActive = false
      sietchActive = false
      sietchMenuMode = .root
      gameState.reset()
      story.newGame()
      if let slot = DevHarness.shared.loadSlot, SaveGame.shared.load(slot) {
          gameState.reset() // the clock from the loaded segment
      }

      showUI()
      showCurrentPlace()
      if let phase = DevHarness.shared.startPhase {
          // Through each chapter's callback (doors, people, visions), then
          // the phase itself; the scenes they ask for are skipped.
          var p: UInt8 = 4
          while p <= phase { story.setGamePhase(p); p += 4 }
          story.setGamePhase(phase)
          _ = story.takePendingScene()
          showCurrentPlace()
      }
      DevHarness.shared.handlers["scene"] = { [weak self] argument in
          guard let self = self, let script = UInt16(argument, radix: 16) else { return }
          self.startScene(script)
      }
      DevHarness.shared.handlers["point"] = { [weak self] argument in
          let parts = argument.split(separator: ",").compactMap { Int($0) }
          guard let self = self, self.mapActive, parts.count == 2 else { return }
          self.flatMap.choosePoint(latitude: parts[0], longitude: UInt16(truncatingIfNeeded: parts[1]))
          self.publishMapUI()
      }
      DevHarness.shared.handlers["place"] = { [weak self] argument in
          guard let self = self, self.mapActive, let index = Int(argument) else { return }
          self.flatMap.choose(index)
          self.publishMapUI()
      }
    }
  
    func showRoom() {
        updateMusic()

        guard let record = world.currentRoomRecord() else {
            engine.logger.log(.error, "showRoom(): no room \(currentGameRoom) for place type \(world.placeType)")
            return
        }
        let salIndex = record.salRoom
        let roomPresentation = PalaceRoom(rawValue: salIndex) ?? .porch
        let roomParams: [String: Any] = [
            "room": roomPresentation,
            "salRoom": salIndex,
            "gameRoomID": currentGameRoom,
            "sheet": world.sheet(for: record),
            "people": world.peopleInRoom(),
            "salFile": World.salFile(world.placeType),
            "outdoor": world.isOutdoors(record, placeType: world.placeType)
        ]
        var params = roomParams
        if let dialogueCharacter = dialogueCharacter {
            params["character"] = dialogueCharacter
        }

        if let palaceNode = findNode("Palace") {
          palaceNode.params = params
          if !palaceNode.isActive {
            setNodeActive("Palace", true)
          }
        } else {
          let palaceNode = Palace()
          palaceNode.params = params
          attachNode(palaceNode)
          setNodeActive("Palace", true)
        }
    }


    /// Shows wherever the data segment says Paul is (new game or a load).
    func showCurrentPlace() {
        if world.placeType <= Location.sietchMax && world.currentRoomRecord() != nil {
            if findNode("Sietch") == nil {
                attachNode(Sietch())
            }
            gameState.setLocation(world.currentLocation)
            sietchActive = true
            sietchMenuMode = .root
            setNodeActive("Palace", false)
            publishSietchRoom()
            setNodeActive("Sietch", true, .background)
            setNodeActive("UI", true, .foreground)
            publishSietchUI(items: sietchRootCharacterItems())
            return
        }
        sietchActive = false
        setNodeActive("Sietch", false)
        if world.currentRoomRecord() == nil {
            engine.logger.log(.warn, "showCurrentPlace: no room \(world.room) at place type \(world.placeType), showing the palace front")
            world.setPosition(location: 0, room: 1)
        }
        showRoom()
        publishMainUI()
    }


    // MARK: - Flat map and travel

    private var flatMap: FlatMap {
        if let map = findNode("FlatMap") as? FlatMap { return map }
        let map = FlatMap()
        attachNode(map)
        return map
    }

    /// SEE DUNE MAP (caption: the DUNE MAP box) or leaving a place (select).
    private func openMap(select: Bool, caption: Bool, riding: Bool = false) {
        self.riding = riding
        dialogueCharacter = nil
        mapActive = true
        let map = flatMap
        map.params = ["select": select, "caption": caption]
        setNodeActive("FlatMap", true, .background)
        publishMapUI()
    }

    private func closeMap() {
        mapActive = false
        movingTroop = nil
        setNodeActive("FlatMap", false)
        if inDesert { showDesert() } else { showCurrentPlace() }
    }

    private enum MapRow { case exit, fly, worm, moveDone, orders, contact, density, takeOrnithopter, prospectors }

    /// map_setup_main_menu (seg000:878c): EXIT MAPS; GO THERE FLYING AN
    /// ORNI once a place is chosen; GIVE ORDERS TO TROOP within a contact
    /// range under 2 (greyed without a hired troop here), else CONTACT
    /// FREMEN TROOPS (greyed without rallied troops); SEE SPICE DENSITY
    /// (greyed before phase 5); TAKE AN ORNITHOPTER (greyed without one
    /// parked here); FIND PROSPECTORS from phase 5.
    private func mapRows() -> [(row: MapRow, id: UInt16, greyed: Bool)] {
        var rows: [(row: MapRow, id: UInt16, greyed: Bool)] = []
        let text = GameText.shared
        func add(_ row: MapRow, _ caption: String, _ greyed: Bool = false) {
            if let id = text.findCommand(caption) { rows.append((row, UInt16(id), greyed)) }
        }
        let map = flatMap
        let phase = world.b(World.phase)
        add(.exit, "EXIT MAPS")
        if let _ = movingTroop {
            if map.destination != nil { add(.moveDone, "  Done") }
            return rows
        }
        if map.selecting, (map.destination.map { $0 != world.currentLocation || inDesert } ?? false) || map.point != nil {
            add(.fly, riding ? "GO THERE RIDING A WORM" : "GO THERE FLYING AN ORNI")
        } else if !map.selecting, let destination = map.destination, destination != world.currentLocation,
                  world.canTravelByWorm {
            // seg000:5ff9: once a worm was ridden the place's popup offers it.
            add(.worm, "GO THERE RIDING A WORM")
        }
        if world.w(0x1176) < 2 {
            add(.orders, "GIVE ORDERS TO TROOP", world.localTroop(hired: true) == nil)
        } else {
            add(.contact, "CONTACT FREMEN TROOPS", world.b(World.fremenTroops) == 0)
        }
        add(.density, map.density ? "STANDARD VISION" : "SEE SPICE DENSITY", phase < 5)
        if !map.selecting {
            let parked = world.location(world.currentLocation).ornithopters > 0 || world.placeType == Location.palace
            add(.takeOrnithopter, "TAKE AN ORNITHOPTER", !parked)
        }
        if phase >= 5 { add(.prospectors, "FIND PROSPECTORS") }
        return Array(rows.prefix(5))
    }

    private func publishMapUI() {
        let rows = mapRows()
        EventManager.uiStateChangedEvent.notify(UIStateEventData(
            leftPanel: .map,
            rightPanel: .mapDirections,
            items: rows.map { $0.id },
            directions: [],
            day: gameState.day,
            phase: gameState.phase,
            greyed: rows.map { $0.greyed }
        ))
    }

    private func handleMapClick(_ point: DunePoint) {
        let map = flatMap
        if let arrow = FlatMap.arrow(at: point) {
            if arrow == (0, 0) {
                map.centreOn(world.currentLocation)
            } else {
                map.scroll(dx: arrow.dx, dy: arrow.dy)
            }
            return
        }
        if map.tap(point) {
            publishMapUI()
            return
        }
        guard menuRect.contains(point) else { return }
        let rows = mapRows()
        let index = Int((point.y - menuRect.y) / 8)
        guard index >= 0 && index < rows.count, !rows[index].greyed else { return }
        switch rows[index].row {
        case .exit:
            closeMap()
        case .takeOrnithopter:
            map.params = ["select": true, "caption": false]
            publishMapUI()
        case .fly:
            if let destination = map.destination {
                fly(to: destination)
            } else if let point = map.point {
                fly(toLatitude: point.latitude, longitude: point.longitude)
            }
        case .density:
            map.density.toggle()
            publishMapUI()
        case .worm:
            if let destination = map.destination {
                riding = true
                fly(to: destination)
            }
        case .moveDone:
            if let troop = movingTroop, let destination = map.destination {
                let accepted = world.issueMoveOrder(troop: troop, to: destination)
                engine.logger.log(.info, "Troops: troop \(troop) \(accepted ? "moves" : "refuses to move") to \(destination)")
                movingTroop = nil
                closeMap()
            }
        case .prospectors:
            // Centre on the prospectors (troop 3); their contact popup is
            // not ported yet.
            if let place = world.troopPlace(3) {
                map.choose(place)
                publishMapUI()
            }
        case .orders, .contact:
            break // the troop contact popup is not ported yet
        }
    }

    /// Take off from room 1 (one ornithopter less here) and fly: one cell
    /// every 3,834 ms; a tap or SKIP TO DESTINATION lands at once.
    private func fly(to destination: Int) {
        mapActive = false
        setNodeActive("FlatMap", false)
        setNodeActive("Palace", false)
        setNodeActive("Sietch", false)
        sietchActive = false

        let to = world.location(destination)
        let origin = travelOrigin()
        let cells = world.cellDistance(fromLatitude: origin.latitude, longitude: origin.longitude,
                                       toLatitude: Int(to.latitude), longitude: to.longitude)
        leaveForFlight()
        flight = (destination, cells, clock + Double(max(1, cells)) * Game.stepSeconds)
        flightPoint = nil
        engine.logger.log(.info, "Flight: \(world.currentLocation) -> \(destination), \(cells) cells")
        startFlightView(from: origin, to: (Int(to.latitude), to.longitude))
    }

    /// Where a flight starts: the place, or the desert point Paul stands on.
    private func travelOrigin() -> (latitude: Int, longitude: UInt16) {
        if inDesert, let here = desertPosition { return here }
        let l = world.location(world.currentLocation)
        return (Int(l.latitude), l.longitude)
    }

    /// Take-off: from a place's room 1 with one ornithopter less there.
    private func leaveForFlight() {
        mapActive = false
        setNodeActive("FlatMap", false)
        setNodeActive("Palace", false)
        setNodeActive("Sietch", false)
        setNodeActive("OpenDesert", false)
        sietchActive = false
        if riding {
            world.rideWorm() // no ornithopter; the first ride sets phase 0x50
        } else if !inDesert {
            world.adjustOrnithopters(world.currentLocation, -1)
            world.setRoom(1)
        }
        inDesert = false
    }

    /// GO THERE FLYING AN ORNI to a desert point.
    private func fly(toLatitude latitude: Int, longitude: UInt16) {
        let origin = travelOrigin()
        let cells = world.cellDistance(fromLatitude: origin.latitude, longitude: origin.longitude,
                                       toLatitude: latitude, longitude: longitude)
        leaveForFlight()
        flight = (-1, cells, clock + Double(max(1, cells)) * Game.stepSeconds)
        flightPoint = (latitude, longitude)
        engine.logger.log(.info, "Flight: to the desert at \(longitude)/\(latitude), \(cells) cells")
        startFlightView(from: origin, to: (latitude, longitude))
    }

    private func startFlightView(from: (latitude: Int, longitude: UInt16), to: (latitude: Int, longitude: UInt16)) {
        // The floppy flight view (FlightLandscape): DUNES.HSQ objects in
        // perspective, seeded from the map cells of the route ahead.
        if findNode("FlightLandscape") == nil { attachNode(FlightLandscape()) }
        setNodeActive("FlightLandscape", true, .background)
        findNode("FlightLandscape")?.params = [
            "dayMode": gameState.phase.lightMode,
            "from": (from.longitude, from.latitude),
            "to": (to.longitude, to.latitude)
        ]
        var items: [UInt16] = []
        if let skip = GameText.shared.findCommand("SKIP TO DESTINATION") { items.append(UInt16(skip)) }
        if let change = GameText.shared.findCommand("CHANGE DESTINATION") { items.append(UInt16(change)) }
        EventManager.uiStateChangedEvent.notify(UIStateEventData(
            leftPanel: .map, rightPanel: .rect, items: items, directions: [],
            day: gameState.day, phase: gameState.phase))
    }

    /// Land: the place is discovered, Paul in its room 1 with one more
    /// ornithopter, a period per 16 cells has passed, then the room-entry
    /// lines.
    private func arrive() {
        guard let trip = flight else { return }
        flight = nil
        setNodeActive("DesertWalk", false)
        setNodeActive("Flight", false)
        setNodeActive("FlightLandscape", false)
        gameState.passPeriods(trip.cells / 16)
        if trip.destination < 0, let point = flightPoint {
            landInDesert(point)
            return
        }
        world.discover(trip.destination)
        world.setPosition(location: trip.destination, room: 1)
        if !riding { world.adjustOrnithopters(trip.destination, 1) }
        riding = false
        gameState.setLocation(trip.destination)
        engine.logger.log(.info, "Flight: landed at \(trip.destination) (\(world.locationName(trip.destination, GameText.shared.command)))")
        // location_related_to_dying_if_arriving_at_fortress (seg000:503c):
        // a place in battle takes Paul into it; a hostile one shoots him.
        if world.nightAttackCheck(at: trip.destination) == .shot { return }
        showCurrentPlace()
        roomEntryScan()
    }


    /// Where Paul stands in the open desert (not in the segment's layout;
    /// the flight's point).
    private var desertPosition: (latitude: Int, longitude: UInt16)?

    private func landInDesert(_ point: (latitude: Int, longitude: UInt16)) {
        inDesert = true
        desertPosition = point
        world.setB(8, 0xFF)
        idleTime = 0
        engine.logger.log(.info, "Desert: Paul lands in the open desert")
        showDesert()
    }

    private enum DesertRow { case map, worm, wait, ornithopter }

    /// Outside a place (seg000:2faa): SEE DUNE MAP, CALL A WORM (greyed
    /// before phase 0x4F; worms are not ported), WAIT FOR EVENING before
    /// period 11 else WAIT FOR MORNING, TAKE AN ORNITHOPTER.
    private func desertRows() -> [(row: DesertRow, id: UInt16, greyed: Bool)] {
        var rows: [(row: DesertRow, id: UInt16, greyed: Bool)] = []
        let text = GameText.shared
        func add(_ row: DesertRow, _ caption: String, _ greyed: Bool = false) {
            if let id = text.findCommand(caption) { rows.append((row, UInt16(id), greyed)) }
        }
        add(.map, "SEE DUNE MAP")
        add(.worm, "CALL A WORM", !world.canCallWorm)
        add(.wait, world.hour < 11 ? "WAIT FOR EVENING" : "WAIT FOR MORNING")
        add(.ornithopter, "TAKE AN ORNITHOPTER")
        return rows
    }

    private func showDesert() {
        if findNode("OpenDesert") == nil { attachNode(OpenDesert()) }
        setNodeActive("Palace", false)
        setNodeActive("Sietch", false)
        setNodeActive("OpenDesert", true, .background)
        let rows = desertRows()
        EventManager.uiStateChangedEvent.notify(UIStateEventData(
            leftPanel: .bookClosed, rightPanel: .roomDirections, items: rows.map { $0.id }, directions: [],
            day: gameState.day, phase: gameState.phase, greyed: rows.map { $0.greyed }))
    }

    private func handleDesertRow(_ index: Int) {
        let rows = desertRows()
        guard index >= 0 && index < rows.count, !rows[index].greyed else { return }
        switch rows[index].row {
        case .map:
            setNodeActive("OpenDesert", false)
            openMap(select: false, caption: true)
        case .ornithopter:
            setNodeActive("OpenDesert", false)
            openMap(select: true, caption: false)
        case .wait:
            // To period 12 (evening) or to the next period 0 (morning). The
            // wait counts as idle time for the first vision.
            let target = world.hour < 11 ? 12 : 16
            gameState.passPeriods(target - world.hour)
            idleTime += 5
            showDesert()
        case .worm:
            setNodeActive("OpenDesert", false)
            openMap(select: true, caption: false, riding: true)
        }
    }


    // MARK: - Music

    /// The game-relative jukebox (seg000:ad5e): the situation's song; a
    /// forced one switches at once, a queued one only when nothing plays yet.
    private func updateMusic() {
        var screen = MusicSituation.Screen()
        screen.talking = conversation != nil || dialogueCharacter != nil
        screen.ending = isOverlayActive("Ending")
        screen.globe = isOverlayActive("Fresk")
        screen.map = mapActive
        screen.vision = dreaming
        screen.travelling = flight != nil || inDesert
        guard let song = MusicSituation.song(screen, world), song.name != currentSong else { return }
        if !song.forced && currentSong != nil { return }
        currentSong = song.name
        engine.audioPlayer.play(Music(song.name, player: engine.audioPlayer))
    }


    // MARK: - Scripted scenes

    /// A " Continue..." sequence read from the executable (seg000:1707).
    private func startScene(_ script: UInt16) {
        let bytes = world.sceneScript(script)
        guard !bytes.isEmpty else {
            engine.logger.log(.warn, "Scene: script \(String(script, radix: 16)) not found")
            return
        }
        scene = bytes
        sceneCursor = 0
        sceneActive = true
        sceneReturnRoom = world.room
        engine.logger.log(.info, "Scene: script \(String(script, radix: 16)) starts")
        sceneStep()
    }

    /// menu_callback_choice_continue (seg000:171a): the next action byte
    /// (a byte offset into the table at cs:1475); 0xFF ends the scene.
    private func sceneStep() {
        func arg() -> Int { sceneCursor < scene.count ? Int(scene[sceneCursor]) : 0xFF }
        while sceneActive && sceneCursor < scene.count {
            let op = scene[sceneCursor]
            sceneCursor += 1
            if op == 0xFF { break }
            switch op {
            case 0x00, 0x12:
                // [room, count, cast...]: the shot (sub_113c8); 0x12 through a transition.
                let room = arg(); sceneCursor += 1
                let count = arg()
                var cast: [Int] = []
                for i in 0..<count where sceneCursor + 1 + i < scene.count { cast.append(Int(scene[sceneCursor + 1 + i])) }
                sceneCursor += 1 + count
                world.setRoom(room)
                if let palace = findNode("Palace"), let record = world.currentRoomRecord() {
                    palace.params = ["room": PalaceRoom(rawValue: record.salRoom) ?? .porch, "salRoom": record.salRoom,
                                     "gameRoomID": room, "sheet": world.sheet(for: record), "people": [Int](),
                                     "cast": cast, "salFile": World.salFile(world.placeType),
                                     "outdoor": world.isOutdoors(record, placeType: world.placeType)]
                    setNodeActive("Palace", true, .background)
                }
                setNodeActive("ScenePicture", false)
            case 0x04:
                break // redraw, step on
            case 0x02:
                // [speaker]: the speaker's next list-7 line (seg000:9761).
                let who = arg(); sceneCursor += 1
                sceneLine(who)
                return
            case 0x06:
                sceneCursor += 1 // [speaker]: the head, silent
            case 0x08:
                waitForContinue() // " Continue..."
                return
            case 0x0A:
                // The evening comes; CHANKISS sprite 0 at (78,33).
                while world.hour < 13 { gameState.passPeriods(1) }
                showScenePicture(["kiss": 1])
                waitForContinue()
                return
            case 0x0C:
                showScenePicture(["kiss": 2]) // CHANKISS sprite 1 at (26,4)
                waitForContinue()
                return
            case 0x0E, 0x10:
                sceneLine(World.fremenChief) // the prospector's lesson
                return
            case 0x14:
                showScenePicture(["final": 1]) // FINAL.HSQ
                waitForContinue()
                sceneCursor -= 1; scene[sceneCursor] = 0x15 // the second picture next
                return
            case 0x15:
                showScenePicture(["final": 2])
                waitForContinue()
                return
            case 0x16:
                // The cast list, then the game is over.
                sceneActive = false
                setNodeActive("ScenePicture", false)
                showEnding(277, through: 289)
                return
            default:
                engine.logger.log(.warn, "Scene: action byte \(String(op, radix: 16)) not ported")
            }
        }
        endScene()
    }

    private func sceneLine(_ who: Int) {
        dialogueCharacter = duneCharacter(number: who)
        if let palace = findNode("Palace"), let character = dialogueCharacter {
            palace.params = ["character": character]
        }
        conversation = Conversation(story: story, character: min(who, World.fremenChief), list: 7, mask: 0x80,
                                    oneList: true, single: true)
        if !showNextConversationPage() { return }
    }

    private func waitForContinue() {
        sceneWaiting = true
        var items: [UInt16] = []
        if let row = GameText.shared.findCommand(" Continue") { items.append(UInt16(row)) }
        EventManager.uiStateChangedEvent.notify(UIStateEventData(
            leftPanel: .bookClosed, rightPanel: .roomDirections, items: items, directions: [],
            day: gameState.day, phase: gameState.phase))
    }

    private func showScenePicture(_ params: [String: Any]) {
        if findNode("ScenePicture") == nil { attachNode(ScenePicture()) }
        findNode("ScenePicture")?.params = params
        setNodeActive("ScenePicture", true, .foreground)
    }

    /// seg000:11736: back to the room the scene started in.
    private func endScene() {
        sceneActive = false
        sceneWaiting = false
        setNodeActive("ScenePicture", false)
        dialogueCharacter = nil
        engine.logger.log(.info, "Scene: over")
        world.setRoom(sceneReturnRoom > 0 ? sceneReturnRoom : world.room)
        showCurrentPlace()
    }


    // MARK: - Endings

    /// An ending (COMMAND 175-180): its text on black; a tap restarts.
    private func showEnding(_ command: Int, through last: Int? = nil) {
        engine.logger.log(.info, "Ending: COMMAND \(command)")
        conversation = nil
        dialogueCharacter = nil
        mapActive = false
        flight = nil
        if findNode("Ending") == nil { attachNode(EndingScreen()) }
        let text = (command...(last ?? command)).map { GameText.shared.command($0) }.joined(separator: "  ")
        findNode("Ending")?.params = ["text": text]
        setNodeActive("Ending", true, .foreground)
        var items: [UInt16] = []
        if let restart = GameText.shared.findCommand("RESTART GAME") { items.append(UInt16(restart)) }
        EventManager.uiStateChangedEvent.notify(UIStateEventData(
            leftPanel: .bookClosed, rightPanel: .rect, items: items, directions: [],
            day: gameState.day, phase: gameState.phase))
    }


    // MARK: - Visions

    /// idle_room_message_check (seg000:2b2a): at phase 0x14, alone in the
    /// desert for 4,993 ms, the first vision; later the queued visions, in
    /// person after 250 ms when the sender is here, else as a dream after
    /// 2,247 ms.
    private func checkIdle(_ elapsed: TimeInterval) {
        let busy = mapActive || flight != nil || dialogueCharacter != nil || conversation != nil
            || isOverlayActive("Dialogue") || isOverlayActive("Book") || isOverlayActive("Fresk")
            || isOverlayActive("Communication")
        if busy { idleTime = 0; return }
        idleTime += elapsed
        let phase = world.b(World.phase)
        if phase < 0x14 { return }
        if phase == 0x14 {
            if inDesert && world.w(World.personsWith) == 0 && idleTime >= 4.993 {
                world.firstVision()
                story.runPhaseTriggers()
                idleTime = 0
                presentVision(dream: true)
            }
            return
        }
        guard world.visionCount > 0 else { return }
        let sender = Int(world.vision(0).id >> 8)
        let present = sender < 16 && sender != 0x0F && world.peopleInRoom().contains(sender) && !inDesert
        if present && idleTime >= 0.25 {
            presentVision(dream: false)
        } else if idleTime >= 2.247 {
            presentVision(dream: true)
        }
    }

    /// present_vision_message (seg000:2b00): DIALOGUE character 16 list 4,
    /// ds:EA = the id's low byte, spoken by the sender or dreamt over VIS.HSQ.
    private func presentVision(dream: Bool) {
        guard world.visionCount > 0 else { return }
        let vision = world.vision(0)
        world.dequeueVision()
        let sender = UInt8(vision.id >> 8)
        if !dream { world.purgeVisions(sender: sender, location: vision.location) }
        world.setB(World.visionType, UInt8(vision.id & 0xFF))
        engine.logger.log(.info, "Vision: message \(String(vision.id, radix: 16)) (\(dream ? "dream" : "in person"))")
        dreaming = dream
        if dream {
            if findNode("VisionDream") == nil { attachNode(VisionDream()) }
            findNode("VisionDream")?.params = ["character": duneCharacter(number: Int(sender)) ?? DuneCharacter.none]
            setNodeActive("VisionDream", true, .foreground)
        } else if let speaker = duneCharacter(number: Int(sender)) {
            dialogueCharacter = speaker
            showRoomOrSietch()
        }
        conversation = Conversation(story: story, character: 16, list: 4, mask: 0, oneList: true)
        showNextConversationPage()
        world.setB(World.visionType, 0xFF)
        idleTime = 0
    }


    private func showDesert(destinationCode: Int) {
        if findNode("DesertWalk") == nil {
            attachNode(DesertWalk())
        }
        if findNode("Flight") == nil {
            attachNode(Flight())
        }

        // The high-bit value is preserved as the original destination code.
        // We intentionally do not invent a room sequence here: the existing
        // data-backed desert scene is the safe landing view until the binary's
        // desert movement records are decoded.
        if let desert = findNode("DesertWalk") {
            desert.params = [
                "interactive": true,
                "destinationCode": destinationCode,
                "travelStep": gameState.travelStep
            ]
        }
        if let flight = findNode("Flight") {
            flight.params = [
                "dayMode": gameState.phase.lightMode,
                "destinationCode": destinationCode,
                "duration": TimeInterval.greatestFiniteMagnitude
            ]
        }

        desertActive = true
        gameState.setLocation(destinationCode)
        setNodeActive("Palace", false)
        setNodeActive("DesertWalk", true, .background)
        setNodeActive("Flight", true, .foreground)
        setNodeActive("UI", true, .foreground)
        EventManager.uiStateChangedEvent.notify(UIStateEventData(
            leftPanel: .bookClosed,
            rightPanel: .roomDirections,
            items: mainMenuItems,
            directions: .all,
            day: gameState.day,
            phase: gameState.phase
        ))
    }


    private func leaveDesert() {
        desertActive = false
        setNodeActive("DesertWalk", false)
        setNodeActive("Flight", false)
        setNodeActive("FlightLandscape", false)
        showRoom()
        setNodeActive("UI", true, .foreground)
        publishMainUI()
    }


    private func showSietch() {
        if findNode("Sietch") == nil {
            attachNode(Sietch())
        }

        let firstGameplaySietch = gameState.currentLocation == 12
        if firstGameplaySietch {
            gameState.advanceStory(to: 0x01, action: "FIRST SIETCH")
        }
        // Land in room 1 (the SIET0 outdoor view) of the location.
        if world.location(gameState.currentLocation).isSietch {
            world.setPosition(location: gameState.currentLocation, room: 1)
        }
        publishSietchRoom()

        sietchActive = true
        sietchMenuMode = .root
        gameState.setMilestone(firstGameplaySietch ? .firstSietch : .recruitFremen,
                               action: firstGameplaySietch ? "GURNEY SIETCH" : "SIETCH LANDING")
        setNodeActive("Palace", false)
        setNodeActive("DesertWalk", false)
        setNodeActive("Flight", false)
        setNodeActive("FlightLandscape", false)
        setNodeActive("Sietch", true, .background)
        setNodeActive("UI", true, .foreground)
        publishSietchUI(items: sietchRootCharacterItems())
    }


    private func sietchRootCharacterItems() -> [UInt16] {
        // SEE DUNE MAP, then the room's people: COMMAND 109 + character for
        // the named ones, 123 "Fremen" for the troops not hired yet and 124
        // "Fremen Chief" for each hired troop's chief.
        guard world.placeType <= Location.sietchMax else { return [141, 123] }
        var items: [UInt16] = [141]
        for person in world.peopleInRoom() {
            if person <= World.harah {
                items.append(UInt16(109 + person))
            } else if person == World.fremen {
                items.append(123)
            } else if person >= World.fremenChief {
                items.append(UInt16(124 + person - World.fremenChief)) // Fremen Chief, 2nd ..., 8th
            }
        }
        return Array(items.prefix(5))
    }


    private func character(forCommandItem item: UInt16) -> DuneCharacter? {
        switch item {
        case 109: return .leto
        case 110: return .jessica
        case 111: return .thufir
        case 112: return .duncan
        case 113: return .gurney
        case 114: return .stilgar
        case 115: return .liet
        case 116: return .chani
        case 117: return .harah
        case 123: return .fremen1
        case 124...131: return .fremen2
        case 132: return .fremen2
        default: return nil
        }
    }


    private func roomCharacterItems() -> [UInt16] {
        // SEE DUNE MAP, then one row per person in the room: COMMAND 109 +
        // character number (109 Leto ... 117 Harah); in the COMM room
        // (palace room 8) VIEW NEW MESSAGES (202) and MESSAGES ALREADY SEEN
        // (203) once there is a message.
        if world.paulInBattle && world.room == 1 {
            // build_room_command_records in a battle (seg000:2efb).
            return battleRows().map { $0.id }
        }
        var items: [UInt16] = [141]
        for person in world.peopleInRoom() where person <= World.harah {
            items.append(UInt16(109 + person))
        }
        if inCommRoom && world.sightingCount > 0 {
            items = Array(items.prefix(3)) + [202, 203]
        }
        return Array(items.prefix(5))
    }

    private var inCommRoom: Bool { world.placeType == Location.palace && world.room == 8 }

    /// VIEW NEW MESSAGES greyed with nothing unread; MESSAGES ALREADY SEEN
    /// greyed when everything is unread.
    private func roomRowsGreyed(_ items: [UInt16]) -> [Bool] {
        if world.paulInBattle && world.room == 1 {
            return battleRows().map { $0.greyed }
        }
        let unread = Int(world.b(World.unread)), count = world.sightingCount
        return items.map { $0 == 202 ? unread == 0 : $0 == 203 ? unread >= count : false }
    }

    // MARK: - Battles

    private enum BattleRow { case map, massive, wholeDay, worm }

    /// SEE DUNE MAP, MASSIVE ATTACK, FIGHT FOR A WHOLE DAY, CALL A WORM
    /// (greyed before phase 0x4F).
    private func battleRows() -> [(row: BattleRow, id: UInt16, greyed: Bool)] {
        var rows: [(row: BattleRow, id: UInt16, greyed: Bool)] = []
        let text = GameText.shared
        func add(_ row: BattleRow, _ caption: String, _ greyed: Bool = false) {
            if let id = text.findCommand(caption) { rows.append((row, UInt16(id), greyed)) }
        }
        add(.map, "SEE DUNE MAP")
        add(.massive, "MASSIVE ATTACK")
        add(.wholeDay, "FIGHT FOR A WHOLE DAY")
        add(.worm, "CALL A WORM", !world.canCallWorm)
        return rows
    }

    private func handleBattleRow(_ index: Int) {
        let rows = battleRows()
        guard index < rows.count, !rows[index].greyed else { return }
        switch rows[index].row {
        case .map:
            openMap(select: false, caption: true)
        case .massive:
            let won = world.massiveAttack(at: world.currentLocation)
            engine.logger.log(.info, "Battle: massive attack \(won ? "won" : "goes on")")
            showCurrentPlace()
        case .wholeDay:
            let periods = world.fightWholeDay()
            engine.logger.log(.info, "Battle: fought \(periods) periods")
            showCurrentPlace()
        case .worm:
            openMap(select: true, caption: false, riding: true)
        }
    }


    // MARK: - COMM room

    /// The message list: senders' rows (sighting index) newest first, then Cancel.
    private var commRows: [(index: Int?, id: UInt16)] = []

    private func openCommList(seen: Bool) {
        commRows = []
        var i = world.sightingCount - 1
        while i >= 0 && commRows.count < 4 {
            let message = world.sighting(i)
            if (message & 0x80 != 0) == seen {
                commRows.append((i, UInt16(109 + Int(message & 0x3F))))
            }
            i -= 1
        }
        commRows.append((nil, 150)) // "  Cancel"
        dialogueContext = .comm
        dialogueMenuItems = commRows.map { $0.id }
        publishDialogueUI()
    }

    /// A message: marked seen, ds:24 = its variant, the sender's list-4 line
    /// with the " Viewed" row (seg000:2864..29d4).
    private func showMessage(_ row: Int) {
        guard row >= 0 && row < commRows.count, let index = commRows[row].index else {
            closeComm()
            return
        }
        let message = world.viewSighting(index)
        world.setB(0x24, message.variant)
        let speaker = duneCharacter(number: message.person) ?? .none
        dialogueCharacter = speaker
        showRoomOrSietch()
        dialogueMenuItems = [204] // " Viewed"
        conversation = Conversation(story: story, character: min(message.person, World.fremenChief), list: 4, mask: 0x80, oneList: true)
        showNextConversationPage()
    }

    private func closeComm() {
        dialogueContext = .palace
        dialogueCharacter = nil
        showRoom()
        publishMainUI()
    }


    private func beginDialogue(with character: DuneCharacter, context: DialogueContext) {
        dialogueContext = context
        lastDialogueCharacter = character
        dialogueCharacter = character
        dialoguePhraseOverride = nil
        dialogueMenuItems = context == .troop ? [66, 68, 67, 69, 72] : talkRows(character)
        showRoomOrSietch()
        publishDialogueUI()
    }


    private func showRoomOrSietch() {
        if sietchActive {
            publishSietchRoom()
            setNodeActive("Sietch", true, .background)
        } else {
            showRoom()
        }
    }


    private func publishDialogueUI(greyed: [Bool]? = nil) {
        EventManager.uiStateChangedEvent.notify(UIStateEventData(
            leftPanel: .bookClosed,
            rightPanel: .roomDirections,
            items: dialogueMenuItems,
            directions: sietchActive ? [] : roomDirections(),
            day: gameState.day,
            phase: gameState.phase,
            greyed: greyed
        ))
    }


    private func phraseIndex(for character: DuneCharacter) -> Int {
        let phase = gameState.storyPhase
        switch character {
        case .leto:
            if phase >= 0x15 { return 14 } // Gurney has disappeared
            return phase >= 0x01 ? 5 : 0
        case .jessica:
            if phase >= 0x4c { return 54 } // Duke Leto is dead
            return phase >= 0x15 ? 72 : 53
        case .duncan:
            if gameState.shipmentPending { return 225 }
            return gameState.prospectorFound ? 203 : 204
        case .gurney:
            return gameState.prospectorFound ? 301 : 285
        case .thufir:
            return 17
        case .stilgar:
            return 294
        case .harah:
            return 309
        case .chani:
            return 174
        case .liet:
            return 432
        case .fremen1, .fremen2, .fremen3:
            return 326
        default:
            return 0
        }
    }


    /// Character number of the original tables (DIALOGUE order).
    private func characterNumber(_ character: DuneCharacter) -> Int? {
        switch character {
        case .leto: return World.leto
        case .jessica: return World.jessica
        case .thufir: return World.thufir
        case .duncan: return World.duncan
        case .gurney: return World.gurney
        case .stilgar: return World.stilgar
        case .liet: return World.kynes
        case .chani: return World.chani
        case .harah: return World.harah
        case .smuggler: return World.smuggler
        case .fremen1, .fremen3: return World.fremen
        case .fremen2: return World.fremenChief
        default: return nil
        }
    }


    /// The talk rows (seg000:95xx): TALK TO ME; COME WITH ME, or STAY HERE
    /// for a companion; STOP TALKING.
    private func talkRows(_ character: DuneCharacter) -> [UInt16] {
        // A troop not hired yet: WORK FOR ME (139); a chief: GIVE ORDERS
        // TO TROOP (136).
        if characterNumber(character) == World.fremen { return [133, 139, 137] }
        if characterNumber(character) == World.fremenChief { return [133, 136, 137] }
        guard let number = characterNumber(character), number < World.fremen else { return [133, 137] }
        let with = world.w(World.personsWith) & (UInt16(1) << UInt16(number)) != 0
        return [133, with ? 135 : 134, 137]
    }


    /// COME WITH ME / STAY HERE: the speaker's list 5 or 6 answer (mask
    /// 0x20, one line); unless the answer refused (action 2) the travelling
    /// bit ds:10 flips. Port of ScummVM GameScreen::companionVerb.
    private func companionVerb(_ character: DuneCharacter) {
        guard let number = characterNumber(character), number < World.fremen else { return }
        let bit = UInt16(1) << UInt16(number)
        let with = world.w(World.personsWith) & bit != 0
        let verb = Conversation(story: story, character: number, list: with ? 6 : 5,
                                mask: 0x20, oneList: true, single: true)
        conversation = verb
        showNextConversationPage()
        verb.finishPending()
        world.setB(0x23, 0)

        if verb.gate != 0 {
            if with {
                world.setW(World.personsWith, world.w(World.personsWith) & ~bit)
                world.settleCharacter(number)
                world.removeCompanion(number)
            } else {
                world.setW(World.personsWith, world.w(World.personsWith) | bit)
                if let home = world.addCompanion(number), home < 16 {
                    world.setW(World.personsWith, world.w(World.personsWith) & ~(UInt16(1) << UInt16(home)))
                    world.settleCharacter(home)
                }
            }
        }
        dialogueMenuItems = talkRows(character)
        publishDialogueUI()
    }


    // MARK: - Troops

    private enum TroopMenu { case orders, occupation }
    private var troopMenu: TroopMenu = .orders
    private var troopRows: [(job: UInt8?, id: UInt16)] = []

    /// WORK FOR ME (seg000:95c1): the charisma check, the Fremen's list-5
    /// answer; a pass rallies the troop and the talk goes on with its chief.
    private func workForMe() {
        guard let troop = world.localTroop(hired: false) else { return }
        let agrees = world.troopAgreesToFollow(troop)
        world.setB(0x23, agrees ? 0 : 2)
        let verb = Conversation(story: story, character: World.fremen, list: 5, mask: 0x20, oneList: true, single: true)
        conversation = verb
        showNextConversationPage()
        verb.finishPending()
        world.setB(0x23, 0)
        if agrees && verb.gate != 0 {
            if let phase = world.rallyTroop(troop) {
                story.setGamePhase(phase)
            }
            dialogueCharacter = .fremen2
            dialogueMenuItems = talkRows(.fremen2)
            publishSietchRoom()
        }
        publishDialogueUI()
    }

    /// GIVE ORDERS TO TROOP: the contact verbs that are ported.
    private func openTroopOrders() {
        guard let troop = world.localTroop(hired: true) else { return }
        dialogueContext = .troop
        troopMenu = .orders
        let job = world.troopByte(troop, 3) & 0x0F
        let text = GameText.shared
        troopRows = []
        // The floppy has only CHANGE TROOP OCCUPATION (COMMAND 68).
        if let row = (job == TroopJob.waitingForOrders ? text.findCommand("SELECT TROOP OCCUPATION") : nil)
            ?? text.findCommand("CHANGE TROOP OCCUPATION") {
            troopRows.append((nil, UInt16(row)))
        }
        if let row = text.findCommand("MOVE TROOP") { troopRows.append((0xFD, UInt16(row))) }
        if let row = text.findCommand("NO MORE ORDERS") { troopRows.append((0xFF, UInt16(row))) }
        dialogueMenuItems = troopRows.map { $0.id }
        publishDialogueUI()
    }

    /// The occupation rows (seg000:6a71): a waiting troop takes a
    /// speciality; a spice troop mines or prospects; ecology needs Kynes met.
    private func openOccupationMenu(_ troop: Int) {
        troopMenu = .occupation
        let job = world.troopByte(troop, 3) & 0x0F
        let kynesMet = world.b(0x0A) & 0x20 != 0
        let text = GameText.shared
        var rows: [(UInt8?, String)] = []
        // ECOLOGY is greyed until Kynes is met (ds:0A bit 5, seg000:69b3).
        let ecology: UInt8? = kynesMet ? TroopJob.irrigation : 0xFE
        if job == TroopJob.waitingForOrders {
            rows = [(TroopJob.spiceMining, "SPECIALIZE IN SPICE"), (TroopJob.militaryTraining, "SPECIALIZE IN ARMY"),
                    (ecology, "SPECIALIZE IN ECOLOGY")]
        } else if job & 0x0C == 0 {
            rows = [(TroopJob.spiceMining, "Spice Mining"), (TroopJob.prospecting, "Spice Prospection")]
        } else if job == TroopJob.espionage {
            rows = [(0xFC, "ATTACK")]
        } else if job & 0x0C == 4 {
            // ESPIONAGE greyed without a hidden fort in reach (seg000:69b3).
            rows = [(world.canStartEspionage(troop: troop) ? 0xFB : 0xFE, "ESPIONAGE"),
                    (TroopJob.spiceMining, "SPECIALIZE IN SPICE"), (ecology, "SPECIALIZE IN ECOLOGY")]
        } else {
            rows = [((job & 0x0C) | 1, "ASSEMBLY WIND-TRAP"), (TroopJob.spiceMining, "SPECIALIZE IN SPICE"),
                    (TroopJob.militaryTraining, "SPECIALIZE IN ARMY")]
        }
        rows.append((0xFF, "Cancel"))
        troopRows = rows.compactMap { row in text.findCommand(row.1).map { (row.0, UInt16($0)) } }
        dialogueMenuItems = troopRows.map { $0.id }
        publishDialogueUI(greyed: troopRows.map { $0.job == 0xFE })
    }

    private func handleTroopMenu(_ index: Int) {
        guard index >= 0 && index < troopRows.count, let troop = world.localTroop(hired: true) else { return }
        let row = troopRows[index]
        if row.job == 0xFE { return } // greyed
        switch (troopMenu, row.job) {
        case (.orders, nil):
            openOccupationMenu(troop)
        case (.orders, 0xFD):
            // MOVE TROOP: choose the place on the map, then "Done".
            movingTroop = troop
            dialogueCharacter = nil
            openMap(select: true, caption: false)
        case (.occupation, 0xFB):
            world.startEspionage(troop: troop)
            openTroopOrders()
        case (.occupation, 0xFC):
            if let place = world.troopPlace(troop) { world.startAttack(at: place) }
            openTroopOrders()
        case (_, 0xFF):
            dialogueContext = .sietch
            dialogueMenuItems = talkRows(dialogueCharacter ?? .fremen2)
            publishDialogueUI()
        case (.occupation, let job?):
            world.setTroopOccupation(troop, job)
            engine.logger.log(.info, "Troops: troop \(troop) occupation \(job)")
            openTroopOrders()
        default:
            break
        }
    }


    /// Entering a room (seg000:35b4): ds:23 = 5, the place is visited, and
    /// the first person here with a list-4 line whose condition holds says it.
    private func roomEntryScan() {
        world.setB(0x23, 5)
        world.markVisited()
        defer { world.setB(0x23, 0) }
        for person in world.peopleInRoom() {
            let group = min(person, World.fremenChief)
            guard story.hasLine(character: group, list: 4),
                  let character = duneCharacter(number: person) else { continue }
            dialogueContext = sietchActive ? .sietch : .palace
            lastDialogueCharacter = character
            dialogueCharacter = character
            dialogueMenuItems = talkRows(character)
            showRoomOrSietch()
            conversation = Conversation(story: story, character: group, list: 4, mask: 0x80, oneList: true)
            showNextConversationPage()
            return
        }
    }


    private func duneCharacter(number: Int) -> DuneCharacter? {
        switch number {
        case World.leto: return .leto
        case World.jessica: return .jessica
        case World.thufir: return .thufir
        case World.duncan: return .duncan
        case World.gurney: return .gurney
        case World.stilgar: return .stilgar
        case World.kynes: return .liet
        case World.chani: return .chani
        case World.harah: return .harah
        case World.smuggler: return .smuggler
        case 9: return .baron
        case 10: return .feyd
        case 11: return .emperor
        case World.captain: return .captain
        case World.fremen...: return .fremen1
        default: return nil
        }
    }


    /// TALK TO ME: lists 0-3 of the speaker, mask 0x80.
    private func startConversation(with character: DuneCharacter) -> Bool {
        guard let number = characterNumber(character) else { return false }
        conversation = Conversation(story: story, character: number, list: 0)
        return showNextConversationPage()
    }


    /// Shows the next page; false when the conversation has ended.
    @discardableResult
    private func showNextConversationPage() -> Bool {
        if let conversation = conversation, conversation.awaitingChoice {
            return true
        }
        let page = conversation?.next()
        if page == nil, let conversation = conversation, conversation.awaitingChoice {
            // The bargaining question: ACCEPT / REFUSE / ARGUE (action 4).
            setNodeActive("Dialogue", false)
            dialogueContext = .shipment
            dialogueMenuItems = [226, 227, 228]
            publishDialogueUI()
            return true
        }
        guard let conversation = conversation, let page = page else {
            self.conversation = nil
            setNodeActive("Dialogue", false)
            if dreaming {
                dreaming = false
                setNodeActive("VisionDream", false)
                if inDesert { showDesert() } else { showCurrentPlace() }
                return false
            }
            if sceneActive {
                dialogueCharacter = nil
                sceneStep()
                return false
            }
            // A line may have moved the story (phase, doors, people).
            publishDialogueUI()
            return false
        }
        if findNode("Dialogue") == nil {
            attachNode(DialogueOverlay())
        }
        findNode("Dialogue")?.params = [
            "text": page,
            "speaker": dialogueCharacterName(dialogueCharacter ?? .none),
            "speakerNumber": conversation.character
        ]
        setNodeActive("Dialogue", true, .foreground)
        return true
    }


    private func showDialogueLine() {
        if findNode("Dialogue") == nil {
            attachNode(DialogueOverlay())
        }
        if let dialogue = findNode("Dialogue") {
            dialogue.params = [
                "phraseIndex": dialoguePhraseOverride ?? phraseIndex(for: dialogueCharacter ?? .none),
                "speaker": dialogueCharacterName(dialogueCharacter ?? .none)
            ]
        }
        setNodeActive("Dialogue", true, .foreground)
    }


    private func dialogueCharacterName(_ character: DuneCharacter) -> String {
        switch character {
        case .leto: return "LETO"
        case .jessica: return "JESSICA"
        case .thufir: return "THUFIR"
        case .duncan: return "DUNCAN"
        case .gurney: return "GURNEY"
        case .stilgar: return "STILGAR"
        case .harah: return "HARAH"
        case .chani: return "CHANI"
        case .liet: return "KYNES"
        case .fremen1, .fremen2, .fremen3: return "FREMEN"
        default: return ""
        }
    }


    private func closeDialogueLine() {
        setNodeActive("Dialogue", false)
        dialoguePhraseOverride = nil
        publishDialogueUI()
    }


    private func handleDialogueMenuClick(_ point: DunePoint) {
        let index = Int((point.y - menuRect.y) / 8)
        guard index >= 0 && index < dialogueMenuItems.count else { return }
        let item = dialogueMenuItems[index]

        if dialogueContext == .troop {
            handleTroopMenu(index)
            return
        }

        if dialogueContext == .comm {
            if item == 204 { // " Viewed"
                closeComm()
            } else {
                showMessage(index)
            }
            return
        }

        if dialogueContext == .shipment {
            // ACCEPT (226) = 1, REFUSE (227) = 2, ARGUE (228) = 3; the
            // talk then goes on from the dialogue data.
            let choice: UInt8 = item == 226 ? 1 : item == 227 ? 2 : 3
            world.bargainChoice(choice)
            dialogueContext = sietchActive ? .sietch : .palace
            dialogueMenuItems = talkRows(dialogueCharacter ?? .none)
            conversation?.resume()
            publishDialogueUI()
            showNextConversationPage()
            return
        }

        switch item {
        case 133:
            if let character = dialogueCharacter {
                if !startConversation(with: character) {
                    showDialogueLine()
                }
            }
        case 134, 135:
            if let character = dialogueCharacter {
                companionVerb(character)
            }
        case 136:
            openTroopOrders()
        case 139:
            workForMe()
        case 138: // WHAT ?
            showDialogueLine()
        case 137:
            dialogueCharacter = nil
            dialoguePhraseOverride = nil
            if sietchActive {
                publishSietchUI(items: sietchRootCharacterItems())
            } else {
                publishMainUI()
            }
        default:
            break
        }
    }


    private func roomDirections() -> UIDirection {
        var directions: UIDirection = []
        guard let exits = world.currentRoomRecord()?.exits else { return directions }
        // Locked doors (bit 7) show no arrow until the story opens them.
        func usable(_ value: UInt8) -> Bool {
            switch RoomRecord.decode(value) {
            case .room, .leave: return true
            case .none, .locked, .unknown: return false
            }
        }
        if usable(exits[0]) { directions.insert(.up) }
        if usable(exits[1]) { directions.insert(.right) }
        if usable(exits[2]) { directions.insert(.down) }
        if usable(exits[3]) { directions.insert(.left) }
        return directions
    }


    /// Shows the sietch room Paul is in (World position), with its people.
    private func publishSietchRoom() {
        guard let sietch = findNode("Sietch") else { return }
        let record = world.placeType <= Location.sietchMax ? world.currentRoomRecord() : nil
        var params: [String: Any] = [
            "room": SietchRoom(rawValue: record?.salRoom ?? 8) ?? .room8,
            "people": record != nil ? world.peopleInRoom() : [World.stilgar, World.harah],
        ]
        if let dialogueCharacter = dialogueCharacter {
            params["character"] = dialogueCharacter
        } else {
            params["character"] = DuneCharacter.none
        }
        sietch.params = params
    }


    private func sietchDirections() -> UIDirection {
        var directions: UIDirection = []
        guard world.placeType <= Location.sietchMax, let exits = world.currentRoomRecord()?.exits else { return directions }
        for (i, d) in [UIDirection.up, .right, .down, .left].enumerated() {
            if case .room = RoomRecord.decode(exits[i]) { directions.insert(d) }
            if case .leave = RoomRecord.decode(exits[i]) { directions.insert(d) }
        }
        return directions
    }


    private func moveSietchRoom(_ direction: RoomDirection) {
        guard world.placeType <= Location.sietchMax, let exits = world.currentRoomRecord()?.exits else { return }
        switch RoomRecord.decode(exits[direction.rawValue]) {
        case .room(let room):
            world.setRoom(room)
            publishSietchRoom()
            publishSietchUI(items: sietchRootCharacterItems())
            roomEntryScan()
        case .leave:
            openMap(select: true, caption: false)
        default:
            break
        }
    }


    private func closeSietch() {
        sietchActive = false
        sietchMenuMode = .root
        setNodeActive("Sietch", false)
        // No flat map yet: leaving flies Paul back to the palace front.
        world.setPosition(location: 0, room: 1)
        showRoom()
        setNodeActive("UI", true, .foreground)
        publishMainUI()
    }


    override func update(_ elapsedTime: TimeInterval) {
        // The clock runs only in room and map views; a dialogue, the book or a
        // menu holds it (game_suspend_count, seg000:ef6a).
        let held = dialogueCharacter != nil || isOverlayActive("Dialogue") || isOverlayActive("Book")
            || isOverlayActive("Fresk") || isOverlayActive("Communication")
        if !held && flight == nil {
            gameState.advance(elapsedTime)
        }
        clock += elapsedTime
        if let flight = flight, clock >= flight.arrival {
            arrive()
        }
        checkIdle(elapsedTime)
        updateMusic()
        if let ending = world.pendingEnding, !isOverlayActive("Ending") {
            showEnding(ending)
        }
        if !sceneActive && conversation == nil && !isOverlayActive("Dialogue") && !mapActive && flight == nil,
           let script = story.takePendingScene() {
            startScene(script)
        }
        super.update(elapsedTime)
    }

    
    func showUI() {
        if findNode("UI") == nil {
          attachNode(UI())
        }
        // The panel is drawn over the room (same priority would leave the
        // order to activation order).
        setNodeActive("UI", true, .foreground)
    }
    
    
    func showFresk() {
        if findNode("Fresk") == nil {
          attachNode(Fresk())
        }
        setNodeActive("Fresk", true, .foreground)
    }


    private func showResults() {
        if findNode("Fresk") == nil {
            attachNode(Fresk())
        }
        setNodeActive("Fresk", true, .foreground)
        (findNode("Fresk") as? Fresk)?.showResults()
    }

    func showBook() {
        if findNode("Book") == nil {
          attachNode(Book())
        }
        setNodeActive("Book", true, .foreground)
    }


    override func onDisable() {
        musicStarted = false
        sietchActive = false
    }


    override func onKey(_ key: DuneKeyEvent) {
        idleTime = 0
        if isOverlayActive("Dialogue") {
            if conversation != nil {
                showNextConversationPage()
            } else {
                closeDialogueLine()
            }
            return
        }

        if flight != nil {
            if key.specialKey == .keyReturn || key.char == " " || key.specialKey == .keyEscape {
                arrive() // SKIP TO DESTINATION
            }
            return
        }

        if mapActive, let map = findNode("FlatMap") as? FlatMap {
            switch key.specialKey {
            case .keyUp: map.scroll(dx: 0, dy: -1)
            case .keyDown: map.scroll(dx: 0, dy: 1)
            case .keyLeft: map.scroll(dx: -1, dy: 0)
            case .keyRight: map.scroll(dx: 1, dy: 0)
            case .keyEscape: closeMap()
            default:
                if key.char.lowercased() == "m" { closeMap() }
            }
            return
        }

        if key.char.lowercased() == "g" && !isOverlayActive("Fresk") && !isOverlayActive("Book") {
            showFresk() // Paul's head: the globe and the game menu
            return
        }

        if desertActive {
            if key.specialKey == .keyEscape {
                leaveDesert()
                return
            }

            guard let desert = findNode("DesertWalk") as? DesertWalk else {
                return
            }

            switch key.specialKey {
            case .keyLeft:
                desert.move(.left)
            case .keyRight:
                desert.move(.right)
            case .keyUp:
                desert.move(.up)
            case .keyDown:
                desert.move(.down)
            case .none, .keyReturn, .keyDelete, .keyEscape:
                break
            }
            return
        }

        if sietchActive {
            if dialogueCharacter != nil {
                if key.specialKey == .keyEscape {
                    dialogueCharacter = nil
                    publishSietchUI(items: sietchRootCharacterItems())
                }
                return
            }
            if isOverlayActive("Fresk") {
                if key.specialKey == .keyEscape || key.char.lowercased() == "m" {
                    closeOverlay()
                } else if let fresk = findNode("Fresk") as? Fresk {
                    fresk.onKey(key)
                }
                return
            }

            switch key.specialKey {
            case .keyUp: moveSietchRoom(.up); return
            case .keyRight: moveSietchRoom(.right); return
            case .keyDown: moveSietchRoom(.down); return
            case .keyLeft: moveSietchRoom(.left); return
            default: break
            }
            if key.specialKey == .keyEscape {
                closeSietch()
            } else if key.char.lowercased() == "m" {
                openMap(select: false, caption: true)
            } else if key.char.lowercased() == "b" {
                showBook()
            } else if key.char.lowercased() == "p" {
                gameState.findProspectors()
                publishSietchUI(items: sietchRootCharacterItems())
            }
            return
        }

        if isOverlayActive("Book") || isOverlayActive("Fresk") {
            if let fresk = findNode("Fresk") as? Fresk, fresk.isActive {
                if key.specialKey == .keyEscape || key.char.lowercased() == "m" {
                    closeOverlay()
                } else {
                    fresk.onKey(key)
                }
                return
            }

            if key.specialKey == .keyEscape || key.char.lowercased() == "b" {
                closeOverlay()
            }
            return
        }

        if key.char.lowercased() == "o" {
            gameState.cycleTroopOrder()
            publishMainUI()
            return
        }

        if key.char.lowercased() == "r" {
            showResults()
            return
        }

        if key.char.lowercased() == "p" {
            gameState.findProspectors()
            publishMainUI()
            return
        }

        switch key.specialKey {
        case .keyLeft:
            moveRoom(.left)
        case .keyRight:
            moveRoom(.right)
        case .keyUp:
            moveRoom(.up)
        case .keyDown:
            moveRoom(.down)
        case .keyEscape:
            closeOverlay()
        case .none, .keyReturn, .keyDelete:
            let character = key.char.lowercased()
            if character == "b" {
                showBook()
            } else if character == "m" {
                openMap(select: false, caption: true)
            }
        }
    }


    override func onClick(_ event: DuneMouseClickEvent) {
        idleTime = 0
        if sceneActive && sceneWaiting && !isOverlayActive("Dialogue") {
            sceneWaiting = false
            sceneStep() // " Continue..."
            return
        }
        if isOverlayActive("Ending") {
            setNodeActive("Ending", false)
            world.pendingEnding = nil
            onEnable() // RESTART GAME
            return
        }
        if inDesert && !mapActive && flight == nil && !isOverlayActive("Dialogue") && !isOverlayActive("Fresk")
            && !isOverlayActive("Book") && menuRect.contains(event.point) {
            handleDesertRow(Int((event.point.y - menuRect.y) / 8))
            return
        }
        if isOverlayActive("Dialogue") {
            if conversation != nil {
                showNextConversationPage()
            } else {
                closeDialogueLine()
            }
            return
        }

        if flight != nil {
            // SKIP TO DESTINATION (row 0), a tap on the view, or CHANGE
            // DESTINATION (row 1) back to the map.
            if menuRect.contains(event.point) && Int((event.point.y - menuRect.y) / 8) == 1 {
                flight = nil
                setNodeActive("DesertWalk", false)
                setNodeActive("Flight", false)
                openMap(select: true, caption: false)
            } else {
                arrive()
            }
            return
        }

        if mapActive {
            handleMapClick(event.point)
            return
        }

        if !isOverlayActive("Fresk") && !isOverlayActive("Book") && event.point.x >= 138 && event.point.x < 182
            && event.point.y >= 134 && event.point.y < 160 && dialogueCharacter == nil {
            showFresk() // Paul's head: the globe and the game menu
            return
        }

        if desertActive {
            guard let desert = findNode("DesertWalk") as? DesertWalk else {
                return
            }

            let point = event.point
            if point.y >= 152 && point.x >= 228 {
                if point.x >= 269 && point.x < 279 && point.y >= 162 && point.y < 172 {
                    desert.move(.up)
                } else if point.x >= 284 && point.x < 294 && point.y >= 172 && point.y < 182 {
                    desert.move(.right)
                } else if point.x >= 269 && point.x < 279 && point.y >= 181 && point.y < 191 {
                    desert.move(.down)
                } else if point.x >= 255 && point.x < 265 && point.y >= 172 && point.y < 182 {
                    desert.move(.left)
                }
            }
            return
        }

        if sietchActive {
            if isOverlayActive("Fresk") {
                if let fresk = findNode("Fresk") as? Fresk {
                    if let action = fresk.menuAction(for: event) {
                        switch action {
                        case .close:
                            closeOverlay()
                        case .quit:
                            engine.exitProgram(nil)
                        case .loaded:
                            closeOverlay()
                            gameState.reset()
                            showCurrentPlace()
                        case .restart:
                            closeOverlay()
                            onEnable()
                        case .handled:
                            break
                        }
                    } else {
                        fresk.onClick(event)
                    }
                }
                return
            }

            if dialogueCharacter != nil {
                if menuRect.contains(event.point) {
                    handleDialogueMenuClick(event.point)
                }
                return
            }

            if let direction = panelDirection(at: event.point) {
                moveSietchRoom(direction)
            } else if menuRect.contains(event.point) {
                handleSietchMenuClick(event.point)
            }
            return
        }

        if isOverlayActive("Fresk") {
            if let fresk = findNode("Fresk") as? Fresk {
                if let action = fresk.menuAction(for: event) {
                    switch action {
                    case .close:
                        closeOverlay()
                    case .quit:
                        engine.exitProgram(nil)
                    case .loaded:
                        closeOverlay()
                        gameState.reset()
                        showCurrentPlace()
                    case .restart:
                        closeOverlay()
                        onEnable()
                    case .handled:
                        break
                    }
                } else {
                    fresk.onClick(event)
                }
            }
            return
        }

        if isOverlayActive("Book") {
            if let book = findNode("Book") as? Book,
               let action = book.menuAction(for: event) {
                switch action {
                case .close:
                    closeOverlay()
                case .handled:
                    break
                }
            } else {
                closeOverlay()
            }
            return
        }

        // A talk, or the COMM room's message list (no speaker yet).
        if dialogueCharacter != nil || dialogueContext == .comm {
            if menuRect.contains(event.point) {
                handleDialogueMenuClick(event.point)
            }
            return
        }

        let point = event.point

        if point.y >= 152 && point.x < 90 {
            showBook()
            return
        }

        if point.y >= 152 && point.x >= 228 {
            if let direction = panelDirection(at: point) {
                moveRoom(direction)
            }
            return
        }

        guard menuRect.contains(point) else {
            return
        }

        let index = Int((point.y - menuRect.y) / 8)
        guard index >= 0 && index < mainMenuItems.count else {
            return
        }

        if roomRowsGreyed(mainMenuItems)[index] { return }
        if world.paulInBattle && world.room == 1 {
            handleBattleRow(index)
            return
        }
        switch mainMenuItems[index] {
        case 202:
            openCommList(seen: false)
        case 203:
            openCommList(seen: true)
        case 141:
            openMap(select: false, caption: true)
        case 109, 110, 111, 112, 113, 114, 115, 116, 117, 123, 124, 125, 126, 127, 128, 129, 130, 131, 132:
            // The real room-person table places Leto in 0x200A, appearance
            // 0x0180. In PALACE.SAL room 0 that is marker 0, not intro
            // marker 8. Selecting his command returns to that room with the
            // correct person slot populated.
            guard let speaker = character(forCommandItem: mainMenuItems[index]) else { return }
            beginDialogue(with: speaker, context: .palace)
        case 214:
            showBook()
        default:
            break
        }
    }


    private func isOverlayActive(_ name: String) -> Bool {
        return findNode(name)?.isActive == true
    }


    private func closeOverlay() {
        if isOverlayActive("Book") {
            setNodeActive("Book", false)
        }
        if isOverlayActive("Fresk") {
            setNodeActive("Fresk", false)
        }
        if isOverlayActive("Sietch") {
            sietchActive = false
            setNodeActive("Sietch", false)
        }
        if sietchActive {
            publishSietchUI(items: itemsForSietchMenu())
        } else {
            publishMainUI()
        }
    }


    private func itemsForSietchMenu() -> [UInt16] {
        switch sietchMenuMode {
        case .root: return sietchRootCharacterItems()
        case .orders: return sietchOrderItems
        case .occupation: return sietchOccupationItems
        case .movement: return sietchMovementItems
        }
    }


    private func publishSietchUI(items: [UInt16]) {
        EventManager.uiStateChangedEvent.notify(UIStateEventData(
            leftPanel: .bookClosed,
            rightPanel: .roomDirections,
            items: items,
            directions: sietchDirections(),
            day: gameState.day,
            phase: gameState.phase
        ))
    }


    private func handleSietchMenuClick(_ point: DunePoint) {
        let index = Int((point.y - menuRect.y) / 8)
        guard index >= 0 && index < 5 else { return }

        switch sietchMenuMode {
        case .root:
            let rootItems = sietchRootCharacterItems()
            guard index < rootItems.count else { return }
            switch rootItems[index] {
            case 141:
                openMap(select: false, caption: true)
            case 109, 110, 111, 112, 113, 114, 115, 116, 117, 123, 124, 125, 126, 127, 128, 129, 130, 131, 132:
                guard let speaker = character(forCommandItem: rootItems[index]) else { return }
                beginDialogue(with: speaker, context: .sietch)
            default:
                break
            }
        case .orders:
            guard index < sietchOrderItems.count else { return }
            switch sietchOrderItems[index] {
            case 67:
                gameState.setMilestone(.firstSietch, action: "MODIFY EQUIPMENT")
            case 68:
                sietchMenuMode = .occupation
                publishSietchUI(items: sietchOccupationItems)
            case 69:
                sietchMenuMode = .movement
                publishSietchUI(items: sietchMovementItems)
            case 70:
                gameState.setMilestone(.firstSietch, action: "NEXT TROOP")
            case 71:
                sietchMenuMode = .root
                publishSietchUI(items: sietchRootCharacterItems())
            default:
                break
            }
        case .occupation:
            guard index < sietchOccupationItems.count else { return }
            switch sietchOccupationItems[index] {
            case 106:
                gameState.setTroopOccupation(.spice)
                sietchMenuMode = .orders
                publishSietchUI(items: sietchOrderItems)
            case 107:
                gameState.setTroopOccupation(.army)
                sietchMenuMode = .orders
                publishSietchUI(items: sietchOrderItems)
            case 108:
                gameState.setTroopOccupation(.ecology)
                sietchMenuMode = .orders
                publishSietchUI(items: sietchOrderItems)
            case 71:
                sietchMenuMode = .orders
                publishSietchUI(items: sietchOrderItems)
            default:
                break
            }
        case .movement:
            guard index < sietchMovementItems.count else { return }
            switch sietchMovementItems[index] {
            case 77:
                gameState.setMilestone(.firstSietch, action: "CHANGE DESTINATION")
            case 78:
                gameState.setMilestone(.firstSietch, action: "FLYING ORNI")
                closeSietch()
                showDesert(destinationCode: gameState.currentLocation)
            case 79:
                gameState.setMilestone(.firstSietch, action: "RIDING WORM")
                closeSietch()
                showDesert(destinationCode: gameState.currentLocation)
            case 80, 81:
                gameState.setMilestone(.firstSietch, action: "ADD DESTINATION")
            default:
                break
            }
        }
    }


    private func publishMainUI() {
        mainMenuItems = roomCharacterItems()
        mainMenuCaptions = nil
        let directions = roomDirections()

        EventManager.uiStateChangedEvent.notify(UIStateEventData(
            leftPanel: .bookClosed,
            rightPanel: .roomDirections,
            items: mainMenuItems,
            directions: directions,
            day: gameState.day,
            phase: gameState.phase,
            captions: mainMenuCaptions,
            greyed: roomRowsGreyed(mainMenuItems)
        ))
    }


    private enum RoomDirection: Int {
        case up = 0
        case right = 1
        case down = 2
        case left = 3
    }


    /// The panel compass arrows (dune-re-ref's NAV_PANEL_ROOM rectangles).
    private func panelDirection(at point: DunePoint) -> RoomDirection? {
        if point.x >= 269 && point.x < 279 && point.y >= 162 && point.y < 172 { return .up }
        if point.x >= 284 && point.x < 294 && point.y >= 172 && point.y < 182 { return .right }
        if point.x >= 269 && point.x < 279 && point.y >= 181 && point.y < 191 { return .down }
        if point.x >= 255 && point.x < 265 && point.y >= 172 && point.y < 182 { return .left }
        return nil
    }


    private func moveRoom(_ direction: RoomDirection) {
        dialogueCharacter = nil
        guard let exits = world.currentRoomRecord()?.exits else { return }

        switch RoomRecord.decode(exits[direction.rawValue]) {
        case .room(let room):
            currentGameRoom = room
            showRoom()
            publishMainUI()
            if world.shipmentReady {
                // The agreed spice leaves from the COMM room (sub_12566;
                // its star-field animation is not shown).
                world.shipSpice()
            }
            roomEntryScan()
        case .leave:
            // 252-254 leave the place: the flat map to choose a destination.
            openMap(select: true, caption: false)
        case .none, .locked, .unknown:
            break
        }
    }
}
