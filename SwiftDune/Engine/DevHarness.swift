//
//  DevHarness.swift
//  SwiftDune
//
//  Scripted input + screenshots for testing without a person at the
//  controls (the iOS simulator has no command-line tap). Same idea as the
//  ScummVM engine's dune_dump / regression scripts.
//
//  Environment variables (on the simulator pass them as SIMCTL_CHILD_<name>):
//    DUNE_START=game          skip logo/intro/credits/prologue
//    DUNE_TIME=<n>            start the game clock (ds:2) at n (16 per day)
//    DUNE_LOAD=<slot>         start from DUNE21S<slot>.SAV (0-4 ship with the game)
//    DUNE_LOG_MEMORY=1        log the memory footprint every 5 s
//    DUNE_PHASE=<hex>         start a new game at this story phase (ds:2A)
//  Script actions handled by the game: place:<index>, point:<lat>,<lng>,
//  scene:<hex CD offset>
//    DUNE_SCRIPT=<steps>      ';'-separated "<seconds>:<action>[:<arg>]"
//        key:<esc|ret|del|left|right|up|down|c>   press a key (c = one char)
//        click:<x>,<y>                           click at a game pixel
//        hover:<x>,<y>                           move the pointer only
//        shot:<name>                             write <name>.png (320x200 x3)
//        place:<index>                           tap that place's icon on the flat map
//      Times are seconds since the game loop started.
//  Screenshots go to DuneEngine.outputDirectory/shots/.
//

import Foundation


final class DevHarness {
    static let shared = DevHarness()

    let startInGame: Bool
    let startTime: UInt16?
    let loadSlot: Int?
    let startPhase: UInt8?
    private let logMemory: Bool
    private var nextMemoryLog: TimeInterval = 0

    private struct Step {
        let time: TimeInterval
        let action: String
        let argument: String
    }

    private var steps: [Step] = []
    /// Scene hooks for actions that need game knowledge (e.g. "place").
    var handlers: [String: (String) -> Void] = [:]

    private init() {
        let environment = ProcessInfo.processInfo.environment
        startTime = environment["DUNE_TIME"].flatMap { UInt16($0) }
        loadSlot = environment["DUNE_LOAD"].flatMap { Int($0) }
        logMemory = environment["DUNE_LOG_MEMORY"] != nil
        startPhase = environment["DUNE_PHASE"].flatMap { UInt8($0, radix: 16) }
        startInGame = environment["DUNE_START"]?.lowercased() == "game" || loadSlot != nil

        steps = (environment["DUNE_SCRIPT"] ?? "")
            .split(separator: ";")
            .compactMap { entry in
                let parts = entry.split(separator: ":", maxSplits: 2).map(String.init)
                guard parts.count >= 2, let time = TimeInterval(parts[0]) else { return nil }
                return Step(time: time, action: parts[1], argument: parts.count > 2 ? parts[2] : "")
            }
            .sorted { $0.time < $1.time }
    }


    /// Called once per frame from the game loop, before input is processed.
    func tick(_ gameTime: TimeInterval, _ engine: DuneEngine) {
        if logMemory && gameTime >= nextMemoryLog {
            nextMemoryLog = gameTime + 5
            engine.logger.log(.info, "memory \(String(format: "%.1f", DevHarness.footprintMB())) MB at \(Int(gameTime)) s")
        }
        while let step = steps.first, step.time <= gameTime {
            steps.removeFirst()
            engine.logger.log(.info, "harness \(step.time)s \(step.action) \(step.argument)")
            perform(step, engine)
        }
    }


    /// phys_footprint, what iOS counts against the app's memory limit.
    static func footprintMB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? Double(info.phys_footprint) / 1_048_576 : -1
    }


    private func perform(_ step: Step, _ engine: DuneEngine) {
        switch step.action {
        case "key":
            var key = DuneKeyEvent()
            switch step.argument {
            case "esc": key.specialKey = .keyEscape
            case "ret": key.specialKey = .keyReturn
            case "del": key.specialKey = .keyDelete
            case "left": key.specialKey = .keyLeft
            case "right": key.specialKey = .keyRight
            case "up": key.specialKey = .keyUp
            case "down": key.specialKey = .keyDown
            default: key.char = String(step.argument.prefix(1))
            }
            engine.keyboard.push(key)
        case "click", "hover":
            let xy = step.argument.split(separator: ",").compactMap { Int16($0) }
            guard xy.count == 2 else { return }
            engine.mouse.coordinates = DunePoint(xy[0], xy[1])
            if step.action == "click" {
                engine.mouse.mouseClicks.enqueue(DuneMouseClickEvent(point: engine.mouse.coordinates))
            }
        case "shot":
            engine.renderer.requestScreenshot(3, name: step.argument)
        default:
            if let handler = handlers[step.action] {
                handler(step.argument)
            } else {
                engine.logger.log(.warn, "harness: unknown action \(step.action)")
            }
        }
    }
}
