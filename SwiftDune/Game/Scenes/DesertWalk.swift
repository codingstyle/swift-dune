//
//  DesertWalk.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 16/06/2024.
//

import Foundation

enum DesertMove {
    case up
    case right
    case down
    case left
}

final class DesertWalk: DuneNode {
    private var contextBuffer = PixelBuffer(width: 320, height: 152)
    
    private let desertRect = DuneRect(0, 76, 320, 76)
    private let desertPaletteIndex = 63

    private var dunesSprite: Sprite?
    private var dunes2Sprite: Sprite?
    private var sky: Sky?
    private var dayMode: DuneLightMode = .day
    
    private var transitionIn: TransitionEffect = .none
    private var transitionOut: TransitionEffect = .none
    private var interactive = false
    private var destinationCode = 0
    private var travelStep = 0
    
    init() {
        super.init("DesertWalk")
    }
    
    
    override func onEnable() {
        dunesSprite = Sprite("DUNES.HSQ")
        dunes2Sprite = Sprite("DUNES2.HSQ")
        sky = Sky()
        currentTime = 0.0
        contextBuffer.tag = 0x0000
    }
    
    
    override func onDisable() {
        currentTime = 0.0
        duration = 16.0
        dunesSprite = nil
        dunes2Sprite = nil
        transitionIn = .none
        transitionOut = .none
        sky = nil
        interactive = false
        destinationCode = 0
        travelStep = 0
        contextBuffer.tag = 0x0000
    }
    
    
    override func onParamsChange() {
        if let dayMode = params["dayMode"] {
            self.dayMode = dayMode as! DuneLightMode
        }

        if let interactive = params["interactive"] as? Bool {
            self.interactive = interactive
            self.currentTime = 0.0
            self.contextBuffer.tag = 0x0000
        }

        if let destinationCode = params["destinationCode"] as? Int {
            self.destinationCode = destinationCode
            self.travelStep = 0
            self.contextBuffer.tag = 0x0000
        }

        if let travelStep = params["travelStep"] as? Int {
            self.travelStep = travelStep
        }

        if let duration = params["duration"] {
            self.duration = duration as! TimeInterval
        }
        
        if let transitionInParam = params["transitionIn"] {
            self.transitionIn = transitionInParam as! TransitionEffect
        }

        if let transitionOutParam = params["transitionOut"] {
            self.transitionOut = transitionOutParam as! TransitionEffect
        }
    }
    
    
    override func update(_ elapsedTime: TimeInterval) {
        currentTime += elapsedTime
        
        if !interactive && currentTime > duration {
            EventManager.nodeEndedEvent.notify(NodeEventData(self.name))
            return
        }
        
        guard let sky = sky else {
            return
        }
        
        sky.lightMode = dayMode
        sky.setPalette()
    }


    // Movement keeps the exact palace destination code and updates the shared
    // world state. The desert renderer remains data-backed while the original
    // map-neighbour records are being decoded; it never fabricates a route.
    func move(_ direction: DesertMove) {
        guard interactive else { return }

        switch direction {
        case .up, .right, .down, .left:
            travelStep = (travelStep + 1) % 4
        }
        GameState.shared.recordTravelStep()
        contextBuffer.tag = 0x0000
        currentTime = 0.0
    }
    
    
    override func render(_ buffer: PixelBuffer) {
        guard let dunesSprite = dunesSprite,
              let dunes2Sprite = dunes2Sprite else {
            return
        }

        engine.palette.unstash()

        if contextBuffer.tag != 0x01 {
            drawBackground(buffer)
            
            // Dunes background
            dunesSprite.drawFrame(4, x: 0, y: 78, buffer: contextBuffer, effect: .transform(scale: 0.2))
            dunesSprite.drawFrame(1, x: 34, y: 77, buffer: contextBuffer, effect: .transform(scale: 0.1))
            dunesSprite.drawFrame(6, x: 143, y: 77, buffer: contextBuffer, effect: .transform(scale: 0.2))
            
            dunesSprite.drawFrame(0, x: 260, y: 78, buffer: contextBuffer, effect: .transform(scale: 0.15))
            dunesSprite.drawFrame(4, x: 243, y: 77, buffer: contextBuffer, effect: .transform(scale: 0.2))
            
            dunesSprite.drawFrame(4, x: 83, y: 77, buffer: contextBuffer, effect: .transform(scale: 0.1))
            dunesSprite.drawFrame(2, x: 62, y: 78, buffer: contextBuffer, effect: .transform(scale: 0.15))
            
            // Arrakeen
            dunes2Sprite.drawFrame(16, x: 160, y: 12, buffer: contextBuffer)
            
            // Dunes foreground
            dunesSprite.drawFrame(0, x: 210, y: 72, buffer: contextBuffer)
            dunesSprite.drawFrame(4, x: 10, y: 76, buffer: contextBuffer)

            engine.palette.stash()

            contextBuffer.tag = 0x01
        }

        var fx: SpriteEffect {
            switch transitionIn {
            case .dissolveIn(let fxDuration):
                return .dissolveIn(start: 0.0, duration: fxDuration, current: currentTime)
            default:
                return .none
            }
        }
        
        contextBuffer.render(to: buffer, effect: fx)
    }
    
    
    private func drawBackground(_ buffer: PixelBuffer) {
        guard let sky = sky else {
            return
        }
        
        sky.render(contextBuffer)

        Primitives.fillRect(desertRect, desertPaletteIndex, contextBuffer)
    }
}
