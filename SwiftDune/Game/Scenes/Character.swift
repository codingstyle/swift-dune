//
//  Character.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 30/10/2024.
//

import Foundation


enum DuneCharacter {
  case none
  case leto
  case jessica
  case paul
  case chani
  case harah
  case stilgar
  case liet
  case baron
  case feyd
  case fremen1
  case fremen2
  case fremen3
  case smuggler
  
  var resourceName: String {
    switch self {
    case .leto:
      "LETO.HSQ"
    case .jessica:
      "JESS.HSQ"
    case .paul:
      "PAUL.HSQ"
    case .chani:
      "CHAN.HSQ"
    case .harah:
      "HARA.HSQ"
    case .stilgar:
      "STIL.HSQ"
    case .liet:
      "KYNE.HSQ"
    case .baron:
      "BARO.HSQ"
    case .feyd:
      "FEYD.HSQ"
    case .fremen1:
      "FRM1.HSQ"
    case .fremen2:
      "FRM2.HSQ"
    case .fremen3:
      "FRM3.HSQ"
    case .smuggler:
      "SMUG.HSQ"
    case .none:
      ""
    }
  }
  
  
  var offset: DunePoint {
    switch self {
    case .baron:
      DunePoint(83, 0)
    case .feyd:
      DunePoint(66, 0)
    default:
      .zero
    }
  }
}


final class Character: DuneNode {
  private var characterSprite: Sprite?
  private var character: DuneCharacter = .none
  private var characterOffset: DunePoint = .zero
  
  
  init() {
    super.init("Character")
  }
  
  
  override func onEnable() {
    characterSprite = Sprite(character.resourceName)
  }
  
  
  override func onDisable() {
    characterSprite = nil
    character = .none
    characterOffset = .zero
    currentTime = 0.0
  }
  
  
  override func onParamsChange() {
    if let characterParam = params["character"] {
      self.character = characterParam as! DuneCharacter
      self.characterOffset = self.character.offset
    }
  }
  
  
  override func update(_ elapsedTime: TimeInterval) {
    currentTime += elapsedTime
  }
  
  
  override func render(_ buffer: PixelBuffer) {
    guard let characterSprite = characterSprite else {
      return
    }
    
    // TODO: add ability to chain animations sequentially (play 1, then 2...)
    // Feyd: (1, 4, 4) - Chani: (1, 2) - Liet: (1, 2)
    
    characterSprite.setPalette()
    characterSprite.drawAnimation(0, buffer: buffer, time: currentTime, offset: characterOffset)
  }
}
