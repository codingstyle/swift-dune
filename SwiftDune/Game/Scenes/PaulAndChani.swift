//
//  PaulAndChani.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 26/09/2026.
//

import Foundation

final class PaulAndChani: DuneNode {
    var paul: Character?
    var chani: Character?
  
    init() {
        super.init("PaulAndChani")
    }
  
    
    override func onEnable() {
        paul = Character()
        paul!.params = [
          "character": DuneCharacter.paulInMirror,
          "animations": [0],
        ]
        paul!.isActive = true
        paul!.characterSprite!.replaceAnimationsImageIndex(1, 9)

        chani = Character()
        chani!.params = [
          "character": DuneCharacter.chani,
          "animations": [1, 2]
        ]
        chani!.isActive = true
    }
  
  
    override func onDisable() {
        paul = nil
        chani = nil
    }


    override func update(_ elapsedTime: TimeInterval) {
        guard let paul = paul, let chani = chani else {
          return
        }
  
        chani.update(elapsedTime)
        paul.update(elapsedTime)
    }
  
  
    override func render(_ buffer: PixelBuffer) {
        guard let paul = paul, let chani = chani else {
          return
        }
        
        chani.render(buffer)
        paul.render(buffer)
    }
}
