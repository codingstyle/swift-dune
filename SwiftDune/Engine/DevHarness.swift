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
//    DUNE_SCRIPT=<steps>      ';'-separated "<seconds>:<action>[:<arg>]"
//        key:<esc|ret|del|left|right|up|down|c>   press a key (c = one char)
//        click:<x>,<y>                           click at a game pixel
//        hover:<x>,<y>                           move the pointer only
//        shot:<name>                             write <name>.png (320x200 x3)
//      Times are seconds since the game loop started.
//  Screenshots go to DuneEngine.outputDirectory/shots/.
//

import Foundation


final class DevHarness {
    static let shared = DevHarness()

    let startInGame: Bool

    private struct Step {
        let time: TimeInterval
        let action: String
        let argument: String
    }

    private var steps: [Step] = []

    private init() {
        let environment = ProcessInfo.processInfo.environment
        startInGame = environment["DUNE_START"]?.lowercased() == "game"

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
        while let step = steps.first, step.time <= gameTime {
            steps.removeFirst()
            engine.logger.log(.info, "harness \(step.time)s \(step.action) \(step.argument)")
            perform(step, engine)
        }
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
            engine.logger.log(.warn, "harness: unknown action \(step.action)")
        }
    }
}
