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
    private let engine = DuneEngine.shared
    
    private var contextBuffer = PixelBuffer(width: 320, height: 152)
    private var bookSprite: Sprite?
    
    private let menuItemsBook: [UInt16] = [214, 215, 216, 217, 218]
    
    init() {
        super.init("Book")
    }
    
    
    override func onEnable() {
        bookSprite = Sprite("BOOK.HSQ")
    }
    
    
    override func onDisable() {
        bookSprite = nil
    }
    
    
    override func update(_ elapsedTime: TimeInterval) {
        
        engine.sendEvent(self, .uiFlagsChanged(flags: UIFlags.leftPanelBookOpen.rawValue | UIFlags.rightPanelRect.rawValue))
        engine.sendEvent(self, .uiMenuChanged(items: menuItemsBook))
    }
    
    
    override func render(_ buffer: PixelBuffer) {
        renderCover(buffer)
        //renderPage(buffer)
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
        
        contextBuffer.render(to: buffer, effect: .none)
    }
}
