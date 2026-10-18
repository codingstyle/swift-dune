//
//  DesertWalk.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 16/06/2024.
//

import Foundation

final class DesertWalk: DuneNode {
    private var contextBuffer = PixelBuffer(width: 320, height: 152)

    private var landscape: DesertLandscape?
    private var sky: Sky?
    private var dayMode: DuneLightMode = .day

    init() {
        super.init("DesertWalk")
    }


    override func onEnable() {
        landscape = DesertLandscape()
        sky = Sky()
    }


    override func onDisable() {
        currentTime = 0.0
        duration = 99999.0
        landscape = nil
        transitionIn = .none
        transitionOut = .none
        sky = nil
    }


    override func onParamsChange() {
        if let dayMode = params["dayMode"] {
            self.dayMode = dayMode as! DuneLightMode
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

        if currentTime > duration {
            EventManager.nodeEndedEvent.notify(NodeEventData(self.name))
            return
        }

        guard let sky = sky else {
            return
        }

        sky.lightMode = dayMode
        sky.setPalette()
    }


    override func render(_ buffer: PixelBuffer) {
        guard let sky = sky, let landscape = landscape else {
            return
        }

        let view = viewpoint()
        sky.lightMode = dayMode
        let tall = view.longitude == 0x2001 || view.longitude == 0x3001
        sky.render(contextBuffer, width: 320, at: 0, type: tall ? .large : .narrow)
        Primitives.fillRect(
            DuneRect(0, Int16(DesertLandscape.horizon), 320, UInt8(152 - DesertLandscape.horizon)),
            DesertLandscape.groundColour,
            contextBuffer,
            isOffset: false
        )
        landscape.setPalette()
        landscape.draw(contextBuffer, longitude: view.longitude, latitude: view.latitude, fine: view.fine, key: view.longitude)

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


    /// Outdoors, the walked longitude, latitude and fine. Indoors, the place's
    /// map cell; a village is drawn on the near row, other interiors stay open sand.
    private func viewpoint() -> (longitude: UInt16, latitude: Int, fine: Int) {
        GameState.shared.prepareWorld()
        let position = GameState.shared.getMapPosition()
        let appearance = GameState.shared.locationAppearance
        var fine = Int(appearance >> 8)
        if appearance & 0xFF == 0x80 {
            fine = GameState.shared.locationView().kind == .village ? 1 : 0
        }
        return (position.x, Int(position.lat), fine)
    }
}
