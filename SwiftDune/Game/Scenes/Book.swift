//
//  Book.swift
//  SwiftDune
//
//  Created by Christophe Buguet on 24/08/2024.
//

import Foundation

enum BookTopic {
    case politics
    case paulOnDune
    case spice
    case fremen
}


struct BookChapter {
    var topic: BookTopic
    var name: String
    var enabled: Bool
}


struct BookPage {
    var number: UInt8
    var content: String
    var firstLetter: String
}


/*
 
 PHRASEx2.HSQ -> 421-433
 COMMANDx.HSQ -> 214-218
 
 Letters (starting at frame 4)
 A, D, E, L, O, P, S, T, U
 
 */


final class Book: DuneNode {
    private var contextBuffer = PixelBuffer(width: 320, height: 152)
    private var bookSprite: Sprite?
  
    private let bookTexts: [UInt16] = [
      0x8456, 0x8457, 0x8459, 0x0884, 0x1939, 0x845c,
      0x2199, 0x2a3a, 0x845d, 0x3a79, 0x8461, 0x08ae,
    ]
    
    private let menuItemsBook: [UInt16] = [214, 215, 216, 217, 218]

    private var animationStartTime = 0.0
  
    private var pageIndex = 1
    
    init() {
        super.init("Book")
    }
    
    
    override func onEnable() {
        bookSprite = Sprite("BOOK.HSQ")

        EventManager.uiStateChangedEvent.notify(UIStateEventData(
          items: menuItemsBook
        ))
      
        EventManager.bookStateChangedEvent.addListener(self) { event in
            if event.action == .turnPageLeft && self.pageIndex > 0 {
                self.animationStartTime = self.currentTime
                self.pageIndex -= 1
            }
          
            if event.action == .turnPageRight {
                self.animationStartTime = self.currentTime
                self.pageIndex += 1
            }
        }
    }
    
    
    override func onDisable() {
        EventManager.bookStateChangedEvent.removeListener(self)
      
        bookSprite = nil
        contextBuffer.clearBuffer()
    }
    
    
    override func update(_ elapsedTime: TimeInterval) {
        if currentTime == 0.0 {
            let music = Music("WATER.HSQ", player: engine.audioPlayer)
            engine.audioPlayer.play(music)
        }
    
        currentTime += elapsedTime
    }
    
    
    override func render(_ buffer: PixelBuffer) {
        if pageIndex == 1 {
            renderCover(buffer)
        } else {
            renderPage(buffer)
        }
    }
    

    private func renderCover(_ buffer: PixelBuffer) {
        guard let bookSprite = bookSprite else {
            return
        }
        
        bookSprite.setPalette()

        if contextBuffer.tag != 0x01 {
            contextBuffer.clearBuffer()

            bookSprite.drawFrame(0, x: 0, y: 0, buffer: contextBuffer)
            bookSprite.drawFrame(1, x: 0, y: 0, buffer: contextBuffer)
            bookSprite.drawFrame(2, x: 0, y: 0, buffer: contextBuffer)

            contextBuffer.tag = 0x01
        }
        
        contextBuffer.render(to: buffer, effect: .none)
    }
    
    
    private func renderPage(/*_ page: BookPage, */_ buffer: PixelBuffer) {
        guard let bookSprite = bookSprite else {
            return
        }
        
        bookSprite.setPalette()

        if contextBuffer.tag != 0x02 {
            contextBuffer.clearBuffer()
            
            var y: Int16 = 0
            
            while y < 152 {
                var x: Int16 = 0
                
                while x < 320 {
                    bookSprite.drawFrame(3, x: x, y: y, buffer: contextBuffer)
                    x += 33
                }
                
                y += 29
            }
            
            Primitives.drawLine(DunePoint(0, 0), DunePoint(319, 0), 94, contextBuffer, isOffset: false)
            Primitives.drawLine(DunePoint(0, 0), DunePoint(0, 151), 94, contextBuffer, isOffset: false)
            Primitives.drawLine(DunePoint(319, 0), DunePoint(319, 151), 94, contextBuffer, isOffset: false)
            Primitives.drawLine(DunePoint(0, 151), DunePoint(319, 151), 94, contextBuffer, isOffset: false)

            contextBuffer.tag = 0x02
        }
        
        contextBuffer.render(to: buffer, effect: .pageFlip(start: animationStartTime, duration: animationStartTime + 2.0, current: currentTime))
    }
}


enum BookAction: Equatable {
  case turnPageLeft
  case turnPageRight
  case topic(_ topic: BookTopic)
}


struct BookStateEventData {
  var action: BookAction
}


extension EventManager {
    static let bookStateChangedEvent = DuneEvent<BookStateEventData>()
}
