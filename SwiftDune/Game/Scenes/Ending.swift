//
//  Ending.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 26/09/2026.
//

import Foundation

// PIT tick (4.99253 ms). Fade lengths follow the DOS countdown × 16 ticks,
// and the slideshow hold is the 0x258-tick pause between transition 0x3a scenes.
private enum EndingTiming {
    static let tick = 0.00499253
    static let dottedReveal = 32.0 / 70.0
    static let fadeThroughBlack = 66.0 / 70.0
    static let skyFade = Double(0x28 * 0x10) * tick
    static let stillFade = Double(0x30 * 0x10) * tick
    static let scroll = 152.0 * 6.0 * tick
    static let plateHold = Double(0x12c) * tick
    static let emblemFade = Double(0x20 * 0x10) * tick
    static let slideshowHold = Double(0x258) * tick
    static let roomHold = 4.0
    static let creditsScroll = 54.0

    static var finalScene: TimeInterval {
        stillFade + scroll + plateHold + emblemFade
    }

    static var slideshowBeat: TimeInterval {
        fadeThroughBlack + slideshowHold + fadeThroughBlack
    }
}


struct EndingPaletteFade {
    var start: Int
    var end: Int
    var duration: TimeInterval
}


struct EndingStep {
    var background: DuneNodeParams?
    var foreground: DuneNodeParams?
    var duration: TimeInterval = 60.0
    var transitionIn: TransitionEffect = .none
    var transitionOut: TransitionEffect = .none
    var caption: UInt16?
    var paletteFade: EndingPaletteFade?
    var playWormsuit = false
}


struct FinalFrame {
    var index: UInt16
    var origin: DunePoint
}


final class Ending: DuneNode {
    private var buffer = PixelBuffer(width: 320, height: 152)
    private var queue = Queue<EndingStep>()
    private var currentStep: EndingStep?

    private var currentTransition: TransitionEffect?
    private var currentTransitionStart: TimeInterval = 0.0
    private var needsTransition = false
    private var didStashPaletteFade = false

    private var largeFont: LargeFont?
    private var sentences: Sentence?
    private var sentenceCount: UInt16 = 0

    private let captionOrigin = DunePoint(10, 157)

    init() {
        super.init("Ending")

        attachNode(Arrakeen())
        attachNode(PaulAndChani())
        attachNode(Palace())
        attachNode(Sietch())
        attachNode(Background())
        attachNode(Character())
        attachNode(FinalScene())
        attachNode(FinalPicture())
        attachNode(Credits())
    }


    override func onEnable() {
        largeFont = LargeFont()
        sentences = Sentence(.command, language: .french)
        sentenceCount = sentences?.sentenceCount() ?? 0

        // Action 09 — throne room (HARK room 2). Chani's slot is empty;
        // she stands with Paul in the dual-head overlay. Transition 0x10
        // is the stippled reveal. The sky span (indices 128...239) then
        // fades to black, which opens action 0a.
        queue.enqueue(EndingStep(
            background: DuneNodeParams("Arrakeen", [
                "room": ArrakeenRoom.throne,
                "markers": [
                  0: RoomCharacter.baron,
                  1: RoomCharacter.emperor,
                  2: RoomCharacter.feyd,
                  3: RoomCharacter.fremen2,
                  4: RoomCharacter.fremen2,
                  5: RoomCharacter.fremen2,
                  6: RoomCharacter.fremen2,
                  7: RoomCharacter.fremen2,
                  8: RoomCharacter.fremen2,
                  9: RoomCharacter.fremen2,
                  10: RoomCharacter.stilgar,
                  11: RoomCharacter.gurney,
                  12: RoomCharacter.thufir,
                  13: RoomCharacter.chani,
                  14: RoomCharacter.jessica,
                  15: RoomCharacter.duncan
                ]
            ]),
            foreground: DuneNodeParams("PaulAndChani"),
            duration: EndingTiming.dottedReveal + EndingTiming.roomHold + EndingTiming.skyFade,
            transitionIn: .dissolveIn(duration: EndingTiming.dottedReveal),
            paletteFade: EndingPaletteFade(start: 128, end: 239, duration: EndingTiming.skyFade)
        ))

        // Action 0a — FINAL.HSQ: the still fades up, sprite 3 pushes it
        // down, then sprite 4 fades in.
        queue.enqueue(EndingStep(
            background: DuneNodeParams("FinalScene"),
            duration: EndingTiming.finalScene
        ))

        // Action 0b — end-credits slideshow. Captions are COMMAND entries
        // 0x115 onward (the script id is incremented before each draw, and
        // the lookup decrements it). Transition 0x3a fades through black.
        enqueueSlideshow(
            background: DuneNodeParams("FinalPicture", [
                "frames": [FinalFrame(index: 5, origin: DunePoint(0x40, 0x34))]
            ]),
            caption: nil,
            playWormsuit: true
        )

        var caption: UInt16 = 277

        enqueueSlideshow(
            background: DuneNodeParams("Background", ["backgroundType": BackgroundType.desert]),
            foreground: character(.paul),
            caption: caption
        )
        caption += 1

        enqueueSlideshow(
            background: palace(.porch),
            foreground: character(.leto),
            caption: caption
        )
        caption += 1

        enqueueSlideshow(
            background: palace(.garden),
            foreground: character(.jessica),
            caption: caption
        )
        caption += 1

        enqueueSlideshow(
            background: palace(.armory),
            foreground: character(.gurney),
            caption: caption
        )
        caption += 1

        enqueueSlideshow(
          background: palace(.diningRoom),
          foreground: character(.duncan),
          caption: caption
        )
        caption += 1

        enqueueSlideshow(
          background: DuneNodeParams("Arrakeen", [ "room": ArrakeenRoom.throne ]),
          foreground: character(.emperor),
          caption: caption
        )
        caption += 1

        enqueueSlideshow(
            background: sietch(.room1),
            foreground: character(.harah),
            caption: caption
        )
        caption += 1

        enqueueSlideshow(
          background: palace(.command),
          foreground: character(.thufir),
          caption: caption
        )
        caption += 1
      
      
        enqueueSlideshow(
          background: sietch(.room8),
          foreground: character(.stilgar),
          caption: caption
        )
        caption += 1

        enqueueSlideshow(
            background: DuneNodeParams("Background", ["backgroundType": BackgroundType.baron]),
            foreground: character(.baron),
            caption: caption
        )
        caption += 1

        enqueueSlideshow(
            background: DuneNodeParams("Arrakeen", [ "room": ArrakeenRoom.throne ]),
            foreground: character(.feyd, offset: DunePoint(0x3a, 0)),
            caption: caption
        )
        caption += 1

        enqueueSlideshow(
            background: sietch(.room10),
            foreground: character(.chani),
            caption: caption
        )
        caption += 1

        enqueueSlideshow(
            background: sietch(.garden),
            foreground: character(.liet),
            caption: caption
        )
        caption += 1

        enqueueSlideshow(
            background: DuneNodeParams("Credits", ["embedded": true]),
            caption: caption,
            duration: EndingTiming.fadeThroughBlack + EndingTiming.creditsScroll + EndingTiming.fadeThroughBlack
        )
        caption += 1

        enqueueSlideshow(
            background: DuneNodeParams("FinalPicture", [
                "frames": [
                    FinalFrame(index: 0, origin: .zero),
                    FinalFrame(index: 1, origin: .zero),
                    FinalFrame(index: 2, origin: .zero)
                ]
            ]),
            foreground: DuneNodeParams("PaulAndChani"),
            caption: caption
        )

        EventManager.nodeEndedEvent.addListener(self) { [weak self] nodeData in
            guard let self = self else { return }
            self.onNodeEvent(nodeData)
        }

        guard let nextStep = queue.dequeueFirst() else {
            return
        }

        activateStep(nextStep)
    }


    override func onDisable() {
        queue.empty()
        EventManager.nodeEndedEvent.removeListener(self)
        largeFont = nil
        sentences = nil
        sentenceCount = 0
    }


    override func update(_ elapsedTime: TimeInterval) {
        guard let currentStep = currentStep else { return }

        currentTime += elapsedTime

        if currentTime > currentStep.duration {
            EventManager.nodeEndedEvent.notify(NodeEventData(currentStep.background!.name))
            return
        }

        if currentTime < currentStep.transitionIn.duration || currentTime > currentStep.duration - currentStep.transitionOut.duration {
            if !needsTransition && currentTransition == nil {
                needsTransition = true
            }

            if currentTime < currentStep.transitionIn.duration {
                currentTransition = currentStep.transitionIn
                currentTransitionStart = 0.0
            } else if currentTime > currentStep.duration - currentStep.transitionOut.duration {
                currentTransition = currentStep.transitionOut
                currentTransitionStart = currentStep.duration - currentStep.transitionOut.duration
            }

            return
        } else {
            currentTransition = nil
        }

        activeNodes.forEach { node in
            node.update(elapsedTime)
        }
    }


    override func render(_ screenBuffer: PixelBuffer) {
        guard let currentStep = currentStep else { return }

        if needsTransition {
            renderStep(into: buffer)
            prepareCaptionPalette()
            engine.palette.stash()
            needsTransition = false
        }

        screenBuffer.clearBuffer()

        if let transition = currentTransition {
            buffer.render(to: screenBuffer, effect: transition.spriteEffect(start: currentTransitionStart, end: currentStep.duration, currentTime: currentTime), y: 0)
            drawCaption(into: screenBuffer)
            return
        }

        renderStep(into: buffer)
        prepareCaptionPalette()
        buffer.copyPixels(to: screenBuffer, offset: 0)
        drawCaption(into: screenBuffer)
        applyPaletteFade(currentStep)
    }


    func onNodeEvent(_ e: NodeEventData) {
        if !self.isActive || !self.isChildNode(e.nodeName) {
            return
        }

        disableStep()

        guard let nextStep = queue.dequeueFirst() else {
            EventManager.nodeEndedEvent.notify(NodeEventData(self.name))
            return
        }

        activateStep(nextStep)
    }


    private func renderStep(into buffer: PixelBuffer) {
        buffer.clearBuffer()

        activeNodes.forEach { node in
            node.render(buffer)
        }
    }


    private func prepareCaptionPalette() {
        guard let caption = currentStep?.caption,
              caption < sentenceCount else {
            return
        }

        largeFont?.setPalette()
    }


    private func drawCaption(into buffer: PixelBuffer) {
        guard let caption = currentStep?.caption,
              let gameFont = largeFont,
              let sentences = sentences,
              caption < sentenceCount else {
            return
        }

        let text = sentences.sentence(at: caption, convertSpecialChars: true)
        gameFont.render(text, x: UInt16(captionOrigin.x), y: UInt16(captionOrigin.y), buffer: buffer)
    }


    private func applyPaletteFade(_ step: EndingStep) {
        guard let fade = step.paletteFade else {
            return
        }

        let fadeStart = step.duration - fade.duration
        guard currentTime > fadeStart else {
            return
        }

        if !didStashPaletteFade {
            engine.palette.stash()
            didStashPaletteFade = true
        }

        let progress = CGFloat((step.duration - currentTime) / fade.duration)
        Effects.fade(progress: Math.clampf(progress, 0.0, 1.0), startIndex: fade.start, endIndex: fade.end)
    }


    private func disableStep() {
        guard let currentStep = currentStep else { return }

        if let backgroundNodeConfig = currentStep.background {
            setNodeActive(backgroundNodeConfig.name, false)
        }

        if let foregroundNodeConfig = currentStep.foreground {
            setNodeActive(foregroundNodeConfig.name, false)
        }

        activeNodes = nodes.sorted().filter { $0.isActive }
        buffer.clearBuffer()

        self.currentStep = nil
        currentTime = 0.0
        currentTransition = nil
        didStashPaletteFade = false
    }


    private func activateStep(_ step: EndingStep) {
        if let backgroundNodeConfig = step.background {
            if let node = findNode(backgroundNodeConfig.name) {
                node.params = backgroundNodeConfig.params
                node.duration = step.duration
                setNodeActive(backgroundNodeConfig.name, true, .background)
            }
        }

        if let foregroundNodeConfig = step.foreground {
            if let node = findNode(foregroundNodeConfig.name) {
                node.params = foregroundNodeConfig.params
                node.duration = step.duration
                setNodeActive(foregroundNodeConfig.name, true, .foreground)
            }
        }

        if step.playWormsuit {
            let music = Music("WORMSUIT.HSQ", player: engine.audioPlayer)
            engine.audioPlayer.play(music)
        }

        activeNodes = nodes.sorted().filter { $0.isActive }
        currentStep = step
    }


    private func enqueueSlideshow(background: DuneNodeParams, foreground: DuneNodeParams? = nil, caption: UInt16?, duration: TimeInterval = EndingTiming.slideshowBeat, playWormsuit: Bool = false) {
        queue.enqueue(EndingStep(
            background: background,
            foreground: foreground,
            duration: duration,
            transitionIn: .fadeIn(duration: EndingTiming.fadeThroughBlack),
            transitionOut: .fadeOut(duration: EndingTiming.fadeThroughBlack),
            caption: caption,
            playWormsuit: playWormsuit
        ))
    }


    private func palace(_ room: PalaceRoom) -> DuneNodeParams {
        DuneNodeParams("Palace", ["room": room, "playMusic": false])
    }


    private func sietch(_ room: SietchRoom) -> DuneNodeParams {
        DuneNodeParams("Sietch", ["room": room])
    }


    private func character(_ character: DuneCharacter, offset: DunePoint? = nil) -> DuneNodeParams {
        var params: [String: Any] = ["character": character]

        if let offset = offset {
            params["offset"] = offset
        }

        return DuneNodeParams("Character", params)
    }
}


// Sprites 0...2 fade up, sprite 3 scrolls down over a 0x8f field, then sprite 4 fades up.
final class FinalScene: DuneNode {
    private var sprite: Sprite?
    private var stillBuffer = PixelBuffer(width: 320, height: 152)
    private var plateBuffer = PixelBuffer(width: 320, height: 152)
    private var plateReady = false
    private var paulAndChani: PaulAndChani?

    init() {
        super.init("FinalScene")
    }


    override func onEnable() {
        sprite = Sprite("FINAL.HSQ")
     
        paulAndChani = PaulAndChani()
        paulAndChani!.onEnable()
        paulAndChani!.isActive = true
        attachNode(paulAndChani!)
    }


    override func onDisable() {
        sprite = nil
        stillBuffer.tag = 0
        stillBuffer.clearBuffer()
        plateBuffer.clearBuffer()
        plateReady = false
        currentTime = 0.0
    }


    override func update(_ elapsedTime: TimeInterval) {
        currentTime += elapsedTime
      
        guard let paulAndChani = paulAndChani else {
          return
        }
      
        paulAndChani.update(elapsedTime)
    }


    override func render(_ buffer: PixelBuffer) {
        guard let sprite = sprite else {
            return
        }

        if stillBuffer.tag == 0 {
            sprite.setPalette()
            drawStill(sprite, into: stillBuffer)
            stillBuffer.tag = 1
            engine.palette.stash()
        }

        if currentTime < EndingTiming.stillFade {
            let progress = CGFloat(currentTime / EndingTiming.stillFade)
          
            Effects.fade(progress: progress, startIndex: 99, endIndex: 174)
            stillBuffer.copyPixels(to: buffer)
          
            guard let paulAndChani = paulAndChani else {
              return
            }
            
            paulAndChani.setPalette()
            paulAndChani.render(stillBuffer)
            return
        }

        if !plateReady {
            sprite.setPalette()
          
            Primitives.fillRect(DuneRect.fullScreen, 0x8f, plateBuffer, isOffset: false)
            sprite.drawFrame(3, x: 0x34, y: 0, buffer: plateBuffer)
          
            engine.palette.stash()
            plateReady = true
        }

        let scrollEnd = EndingTiming.stillFade + EndingTiming.scroll
      
        if currentTime < scrollEnd {
            let progress = CGFloat((currentTime - EndingTiming.stillFade) / EndingTiming.scroll)
            pushDown(progress, into: buffer)
            return
        }

        let holdEnd = scrollEnd + EndingTiming.plateHold
      
        if currentTime < holdEnd {
            plateBuffer.copyPixels(to: buffer)
            return
        }

        plateBuffer.copyPixels(to: buffer)
        sprite.drawFrame(4, x: 0x5a, y: 0x40, buffer: buffer)

        let progress = CGFloat((currentTime - holdEnd) / EndingTiming.emblemFade)
        Effects.fade(progress: Math.clampf(progress, 0.0, 1.0), startIndex: 160, endIndex: 174)
    }


    private func drawStill(_ sprite: Sprite, into buffer: PixelBuffer) {
        var index: UInt16 = 0

        while index < 3 {
            sprite.drawFrame(index, x: 0, y: 0, buffer: buffer)
            index += 1
        }
      }


    // Transition 0x22: the bottom of the new plate enters at the top and moves down.
    private func pushDown(_ progress: CGFloat, into dest: PixelBuffer) {
        let rows = dest.height
        let rowBytes = dest.rowSizeInBytes
        var shown = Int((Math.clampf(progress, 0.0, 1.0) * CGFloat(rows)).rounded(.down))

        if shown < 0 {
            shown = 0
        }

        if shown > rows {
            shown = rows
        }

        var y = 0

        while y < shown {
            let srcY = rows - shown + y
            memcpy(dest.rawPointer + (y * dest.width), plateBuffer.rawPointer + (srcY * plateBuffer.width), rowBytes)
            y += 1
        }

        var oldY = 0

        while y < rows {
            memcpy(dest.rawPointer + (y * dest.width), stillBuffer.rawPointer + (oldY * stillBuffer.width), rowBytes)
            y += 1
            oldY += 1
        }
    }
}


final class FinalPicture: DuneNode {
    private var sprite: Sprite?
    private var frames: [FinalFrame] = []

    init() {
        super.init("FinalPicture")
    }


    override func onEnable() {
        sprite = Sprite("FINAL.HSQ")
        sprite?.setPalette()
    }


    override func onDisable() {
        sprite = nil
        frames = []
        currentTime = 0.0
    }


    override func onParamsChange() {
        if let framesParam = params["frames"] {
            self.frames = framesParam as! [FinalFrame]
        }
    }


    override func render(_ buffer: PixelBuffer) {
        guard let sprite = sprite else {
            return
        }

        var i = 0

        while i < frames.count {
            let frame = frames[i]
            sprite.drawFrame(frame.index, x: frame.origin.x, y: frame.origin.y, buffer: buffer)
            i += 1
        }
    }
}
