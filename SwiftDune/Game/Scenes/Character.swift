//
//  Character.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 30/10/2024.
//

import Foundation


enum DuneCharacter: Equatable {
  case none
  case leto
  case jessica
  case thufir
  case duncan
  case gurney
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
  /// The Emperor (EMPR.HSQ) speaks through the COMM room.
  case emperor
  /// The Harkonnen captain (HARK.HSQ).
  case captain
  
  var resourceName: String {
    switch self {
    case .leto:
      "LETO.HSQ"
    case .jessica:
      "JESS.HSQ"
    case .thufir:
      "HAWA.HSQ"
    case .duncan:
      "IDAH.HSQ"
    case .gurney:
      "GURN.HSQ"
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
    case .emperor:
      "EMPR.HSQ"
    case .captain:
      "HARK.HSQ"
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
  private var animations: [Int] = []
  private var idleAnimation = 0
  private var animationStartTime = 0.0
  private var animationDuration = 0.0
  private var currentAnimation = -1
  
  init() {
    super.init("Character")
  }
  
  
  override func onEnable() {
    characterSprite = Sprite(character.resourceName)
    characterSprite?.setPalette()
  }
  
  
  override func onDisable() {
    characterSprite = nil
    character = .none
    characterOffset = .zero
    currentTime = 0.0
    animationStartTime = 0.0
    animationDuration = 0
    idleAnimation = 0
    currentAnimation = -1
    animations = []
  }
  
  
  override func onParamsChange() {
    if let characterParam = params["character"] {
      self.character = characterParam as! DuneCharacter
      self.characterOffset = self.character.offset
    }
    
    if let animationsParam = params["animations"] {
      self.animations = animationsParam as! [Int]

      if !self.animations.isEmpty {
        self.idleAnimation = self.animations.last!
      }
    }
  }
  
  
  override func update(_ elapsedTime: TimeInterval) {
      currentTime += elapsedTime
  }
  
  
  override func render(_ buffer: PixelBuffer) {
    guard let characterSprite = characterSprite else {
      return
    }
    
    let animationTime = currentTime - animationStartTime
    
    // Play animations or fallback to idle animation (last animation)
    if animationDuration <= animationTime {
      animationStartTime = currentTime
      
      if animations.count > 0 {
        currentAnimation = animations.remove(at: 0)
      } else {
        currentAnimation = idleAnimation
        animationDuration = 99999.9
      }
      
      let animationInfo = characterSprite.animation(at: currentAnimation)
      animationDuration = Double(animationInfo.frames.count) * 0.16
    }
    
    characterSprite.setPalette()
    characterSprite.drawAnimation(UInt16(currentAnimation), buffer: buffer, time: animationTime, offset: characterOffset)
  }
}
