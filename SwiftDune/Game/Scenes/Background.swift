//
//  Background.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 28/10/2024.
//

import Foundation

enum BackgroundType {
    case red
    case baron
    case feyd
    case mirror
    case desert
  
    var resourceName: String {
      switch self {
      case .red, .baron, .feyd:
        return "BACK.HSQ"
      case .mirror:
        return "MIRROR.HSQ"
      case .desert:
        return "INTDS.HSQ"
      }
    }
}

final class Background: DuneNode {
  private var contextBuffer = PixelBuffer(width: 320, height: 152)

  private var backgroundType: BackgroundType = .red
  private var backgroundSprite: Sprite?
  private var sky: Sky?

  private var showSardaukar = false
  private var sardaukarAnimation: DuneAnimation<Int16>?

  
  init() {
    super.init("Background")
  }

  
  override func onEnable() {
    sky = Sky()
    backgroundSprite = Sprite(backgroundType.resourceName)
    
    sardaukarAnimation = DuneAnimation(
      from: Int16(-150),
      to: Int16(0),
      startTime: 2.0,
      endTime: 2.2
    )
  }
  
  
  override func onDisable() {
    backgroundSprite = nil
    sky = nil
    backgroundType = .red
    showSardaukar = false
    sardaukarAnimation = nil
    contextBuffer.clearBuffer()
    contextBuffer.tag = 0x0000
    currentTime = 0.0
  }
  
  
  override func onParamsChange() {
    if let backgroundTypeParam = params["backgroundType"] {
      self.backgroundType = backgroundTypeParam as! BackgroundType
    }
    
    if let sardaukarParam = params["sardaukar"] {
      self.showSardaukar = sardaukarParam as! Bool
    }
  }
  
  
  override func update(_ elapsedTime: TimeInterval) {
    currentTime += elapsedTime
  }
  
  
  override func render(_ buffer: PixelBuffer) {
    if contextBuffer.tag != 0x0001 {
      contextBuffer.clearBuffer()
      
      switch backgroundType {
      case .red:
        drawRedBackground(contextBuffer)
        break
      case .mirror:
        drawMirrorBackground(contextBuffer)
        break
      case .baron:
        drawBaronBackground(contextBuffer)
        break
      case .feyd:
        drawFeydBackground(contextBuffer)
        break
      case .desert:
        drawDesertBackground(contextBuffer)
        break
      }
      
      contextBuffer.tag = 0x0001
    }
    
    contextBuffer.render(to: buffer)
    
    if showSardaukar {
      drawAnimatedSardaukars(buffer, time: currentTime)
    }
  }
  
  
  private func drawRedBackground(_ buffer: PixelBuffer) {
    guard let backgroundSprite = backgroundSprite else {
      return
    }
    
    backgroundSprite.setPalette()
    backgroundSprite.drawFrame(0, x: 0, y: 0, buffer: buffer)
    backgroundSprite.drawFrame(1, x: 52, y: 25, buffer: buffer)
    backgroundSprite.drawFrame(2, x: 108, y: 51, buffer: buffer)
  }
  
  
  private func drawMirrorBackground(_ buffer: PixelBuffer) {
    guard let backgroundSprite = backgroundSprite else {
      return
    }
    
    backgroundSprite.setPalette()
    backgroundSprite.drawFrame(0, x: 0, y: 0, buffer: buffer)
    backgroundSprite.drawFrame(1, x: 0, y: 0, buffer: buffer)
    backgroundSprite.drawFrame(2, x: 0, y: 0, buffer: buffer)
  }

  
  private func drawBaronBackground(_ buffer: PixelBuffer) {
      guard let backgroundSprite = backgroundSprite else {
        return
      }
      
      backgroundSprite.setPalette()
      backgroundSprite.drawFrame(4, x: 0, y: 0, buffer: buffer, effect: .transform(flipX: true, flipY: false))
      backgroundSprite.drawFrame(4, x: 236, y: 0, buffer: buffer)
      backgroundSprite.drawFrame(3, x: 84, y: 0, buffer: buffer)
  }
  
  
  private func drawAnimatedSardaukars(_ buffer: PixelBuffer, time: TimeInterval) {
    guard let backgroundSprite = backgroundSprite,
          let sardaukarAnimation = sardaukarAnimation else {
      return
    }
    
    let x = sardaukarAnimation.interpolate(time)
    
    backgroundSprite.drawFrame(5, x: x, y: 13, buffer: buffer)
    backgroundSprite.drawFrame(6, x: x, y: 13, buffer: buffer)
  }
  
  
  private func drawFeydBackground(_ buffer: PixelBuffer) {
    guard let backgroundSprite = backgroundSprite else {
      return
    }
    
    backgroundSprite.setPalette()
    Primitives.fillRect(DuneRect(84, 0, 152, 152), 48, buffer, isOffset: false)
    
    backgroundSprite.drawFrame(4, x: 0, y: 0, buffer: buffer, effect: .transform(flipX: true))
    backgroundSprite.drawFrame(4, x: 236, y: 0, buffer: buffer)
    
    // Sardaukars
    backgroundSprite.drawFrame(5, x: -53, y: 8, buffer: buffer)
    backgroundSprite.drawFrame(6, x: -53, y: 8, buffer: buffer)
    
    backgroundSprite.drawFrame(5, x: 0, y: 13, buffer: contextBuffer)
    backgroundSprite.drawFrame(6, x: 0, y: 13, buffer: contextBuffer)
    
    backgroundSprite.drawFrame(7, x: 200, y: 13, buffer: contextBuffer)
    backgroundSprite.drawFrame(8, x: 200, y: 13, buffer: contextBuffer)
  }
  
  
  private func drawDesertBackground(_ buffer: PixelBuffer) {
    guard let backgroundSprite = backgroundSprite,
          let sky = sky else {
      return
    }

    // Apply sky gradient with blue palette
    sky.lightMode = .day
    sky.setPalette()
    sky.render(buffer)
    
    // Desert background
    backgroundSprite.setPalette()
    backgroundSprite.drawFrame(0, x: 0, y: 60, buffer: buffer)
  }
}
