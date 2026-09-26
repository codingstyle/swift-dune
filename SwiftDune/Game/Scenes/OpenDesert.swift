//
//  OpenDesert.swift
//  SwiftDune
//
//  Paul in the open desert (flown to a map point, ds:8 = 0xFF): the narrow
//  sky of the hour over sand, (0,78)-(320,152) in colour 190. The floppy
//  also draws DUNES pieces and the parked ornithopter; like the ScummVM
//  engine's drawDesert this leaves them out (their palette is not recovered).
//

import Foundation


final class OpenDesert: DuneNode {
    private var sky: Sky?

    init() {
        super.init("OpenDesert")
    }

    override func onEnable() {
        sky = Sky()
    }

    override func onDisable() {
        sky = nil
    }

    override func render(_ buffer: PixelBuffer) {
        guard let sky = sky else { return }
        sky.lightMode = GameState.shared.phase.lightMode
        sky.render(buffer, width: 320, at: 0, type: .narrow, gameplayPalette: true)
        Primitives.fillRect(DuneRect(0, 78, 320, 74), 190, buffer, isOffset: false)
    }
}


/// A vision dream: VIS.HSQ frame 0 (an 8-bit picture of pink clouds) behind
/// the sender's bust and the line (present_vision_dream, seg000:2bd2; the
/// speed-run recording shows Leto's bust for the first vision), wobbling. The original's wobble is not decoded; each row
/// is shifted by a sine wave (6 px amplitude, 48-row wavelength, one cycle
/// a second) as swift-dune's TODO describes the effect.
final class VisionDream: DuneNode {
    private var vision: Sprite?
    private var portrait: Sprite?
    private let picture = PixelBuffer(width: 320, height: 152)
    private let sky = Sky()

    init() {
        super.init("VisionDream")
    }

    override func onEnable() {
        vision = Sprite("VIS.HSQ")
        currentTime = 0
    }

    override func onDisable() {
        vision = nil
        portrait = nil
    }

    override func onParamsChange() {
        if let character = params["character"] as? DuneCharacter {
            portrait = character == .none ? nil : Sprite(character.resourceName)
        }
    }

    override func update(_ elapsedTime: TimeInterval) {
        currentTime += elapsedTime
    }

    override func render(_ buffer: PixelBuffer) {
        guard let vision = vision else { return }
        picture.clearBuffer()
        // The floppy's VIS frame is only wisps of cloud (4-bit, offset 127);
        // its palette's other colours (to 207) tint the sky tiles drawn
        // behind them. (A reading of the data; the dream routine at
        // seg000:2bd2 is not decoded. The CD's VIS is a full 8-bit picture.)
        sky.render(picture, width: 320, at: 0, type: .narrow, gameplayPalette: true)
        sky.render(picture, width: 320, at: 0, type: .large, gameplayPalette: true)
        // The large sky ends above the panel; its lowest coloured row runs down.
        var horizon = 119
        while horizon > 0 && picture.rawPointer[horizon * picture.width + 160] == 0 { horizon -= 1 }
        for y in (horizon + 1)..<152 {
            (picture.rawPointer + y * picture.width).update(from: picture.rawPointer + horizon * picture.width, count: picture.width)
        }
        vision.setPalette()
        vision.drawFrame(0, x: 0, y: 0, buffer: picture)
        // VIS.HSQ's colours (128-207) must survive the balloon's and the
        // panel's ICONES palette, set after this node draws.
        engine.finalPalettes.append { vision.setPalette() }
        for y in 0..<min(152, buffer.height) {
            let shift = Int((6.0 * sin(2.0 * Double.pi * (Double(y) / 48.0 + currentTime))).rounded())
            for x in 0..<320 {
                let sx = min(max(x + shift, 0), 319)
                buffer.rawPointer[y * buffer.width + x] = picture.rawPointer[y * picture.width + sx]
            }
        }
        if let portrait = portrait {
            portrait.setPalette()
            portrait.drawAnimation(0, buffer: buffer, time: 0)
        }
    }
}


/// An ending's text (COMMAND 175-180) on black, as the original's
/// pending_room_screen_request endings show it.
final class EndingScreen: DuneNode {
    private var font: GameFont?
    private var text = ""

    init() {
        super.init("Ending")
    }

    override func onEnable() {
        font = GameFont()
    }

    override func onDisable() {
        font = nil
    }

    override func onParamsChange() {
        if let text = params["text"] as? String { self.text = text }
    }

    override func render(_ buffer: PixelBuffer) {
        guard let font = font else { return }
        Primitives.fillRect(DuneRect(0, 0, 320, 152), 0, buffer, isOffset: false)
        font.paletteIndex = 250
        font.render(text, rect: DuneRect(24, 20, 272, 112), buffer: buffer, alignment: .center, style: .normal)
    }
}


/// Pictures of the scripted scenes: CHANKISS (sprite 0 at 78,33 or sprite
/// 1 at 26,4, over the room) and FINAL.HSQ (sprites 0-2 at the origin, then
/// 3 at 52,0 and 4 at 90,64), from the draw lists at ds:2290 / seg000:14ac.
final class ScenePicture: DuneNode {
    private var kiss = 0
    private var final = 0
    private lazy var kissSprite = Sprite("CHANKISS.HSQ")
    private lazy var finalSprite = Sprite("FINAL.HSQ")

    init() {
        super.init("ScenePicture")
    }

    override func onParamsChange() {
        kiss = params["kiss"] as? Int ?? 0
        final = params["final"] as? Int ?? 0
    }

    override func render(_ buffer: PixelBuffer) {
        if kiss > 0 {
            let sprite = kissSprite
            sprite.setPalette()
            if kiss == 1 {
                sprite.drawFrame(0, x: 78, y: 33, buffer: buffer)
            } else {
                sprite.drawFrame(1, x: 26, y: 4, buffer: buffer)
            }
        } else if final > 0 {
            let sprite = finalSprite
            sprite.setPalette()
            Primitives.fillRect(DuneRect(0, 0, 320, 152), 0, buffer, isOffset: false)
            if final == 1 {
                for frame: UInt16 in 0..<3 { sprite.drawFrame(frame, x: 0, y: 0, buffer: buffer) }
            } else {
                sprite.drawFrame(3, x: 0x34, y: 0, buffer: buffer)
                sprite.drawFrame(4, x: 0x5A, y: 0x40, buffer: buffer)
            }
        }
    }
}
